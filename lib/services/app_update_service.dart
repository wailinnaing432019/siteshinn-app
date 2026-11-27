import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/config/app_env.dart';

class AppUpdateInfo {
  final String currentVersion;
  final int currentBuild;
  final String latestVersion;
  final int latestBuild;
  final String apkUrl;
  final String releaseNotes;
  final bool forceUpdate;

  const AppUpdateInfo({
    required this.currentVersion,
    required this.currentBuild,
    required this.latestVersion,
    required this.latestBuild,
    required this.apkUrl,
    required this.releaseNotes,
    this.forceUpdate = false,
  });

  bool get hasUpdate => latestBuild > currentBuild && apkUrl.trim().isNotEmpty;
}

class AppUpdateService {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();

  static const MethodChannel _channel = MethodChannel(
    'com.siteshinn.site_shinn/device_settings',
  );

  bool _startupChecked = false;

  Future<({String versionName, int versionCode, List<String> abis})>
      getCurrentVersionInfo() async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'getAppVersionInfo',
      );
      if (raw != null) {
        final name = raw['versionName'] as String? ?? '2.0.0';
        final code = (raw['versionCode'] as num?)?.toInt() ?? 2;
        final abis = (raw['supportedAbis'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList();
        return (versionName: name, versionCode: code, abis: abis);
      }
    } catch (_) {}
    return (
      versionName: '2.0.0',
      versionCode: 2,
      abis: const <String>[],
    );
  }

  static String resolveApkUrl(
    Map<String, dynamic> data,
    List<String> supportedAbis,
  ) {
    final rawMap = data['apk_urls'];
    if (rawMap is Map) {
      final typed = Map<String, dynamic>.from(rawMap);
      for (final abi in supportedAbis) {
        final url = typed[abi]?.toString().trim();
        if (url != null && url.isNotEmpty) return url;
      }
      final universal = typed['universal']?.toString().trim();
      if (universal != null && universal.isNotEmpty) return universal;
    }
    return (data['apk_url'] as String? ?? '').trim();
  }

  Future<AppUpdateInfo?> checkForUpdate({
    required bool isBurmese,
    bool startupOnlyOnce = false,
  }) async {
    if (startupOnlyOnce) {
      if (_startupChecked) return null;
      _startupChecked = true;
    }
    if (!AppEnv.isCloudConfigured) return null;

    try {
      final local = await getCurrentVersionInfo();
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('android')
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 6));

      final data = doc.data();
      if (!doc.exists || data == null) return null;

      final latestBuild = (data['latest_build'] as num?)?.toInt() ?? 0;
      final latestVersion = (data['latest_version'] as String? ?? '').trim();
      final apkUrl = resolveApkUrl(data, local.abis);

      final notesMy = (data['release_notes_my'] as String? ?? '').trim();
      final notesEn = (data['release_notes_en'] as String? ?? '').trim();
      final notes = isBurmese
          ? (notesMy.isNotEmpty ? notesMy : notesEn)
          : (notesEn.isNotEmpty ? notesEn : notesMy);

      final info = AppUpdateInfo(
        currentVersion: local.versionName,
        currentBuild: local.versionCode,
        latestVersion:
            latestVersion.isNotEmpty ? latestVersion : local.versionName,
        latestBuild: latestBuild,
        apkUrl: apkUrl,
        releaseNotes: notes,
        forceUpdate: data['force_update'] as bool? ?? false,
      );

      return info.hasUpdate ? info : null;
    } catch (_) {
      return null;
    }
  }

  Future<String> downloadAndInstallApk(
    AppUpdateInfo info, {
    required void Function(double? progress, int received, int total)
        onProgress,
  }) async {
    final uri = Uri.parse(info.apkUrl);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(uri);
      request.followRedirects = true;
      request.maxRedirects = 8;
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'HTTP ${response.statusCode}',
          uri: uri,
        );
      }

      final tempDir = await getTemporaryDirectory();
      final safeVer =
          info.latestVersion.replaceAll(RegExp(r'[^\w\.\-]+'), '_');
      final apkFile = File(p.join(tempDir.path, 'siteshinn_v$safeVer.apk'));
      final sink = apkFile.openWrite();

      final totalBytes = response.contentLength;
      var receivedBytes = 0;

      await for (final chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        final progress = totalBytes > 0
            ? (receivedBytes / totalBytes).clamp(0.0, 1.0)
            : null;
        onProgress(progress, receivedBytes, totalBytes);
      }

      await sink.flush();
      await sink.close();

      if (await apkFile.length() == 0) {
        throw StateError('Downloaded APK file is empty.');
      }

      final status = await _channel.invokeMethod<String>('installApk', {
        'path': apkFile.path,
      });
      return status ?? 'error';
    } finally {
      client.close(force: true);
    }
  }
}
