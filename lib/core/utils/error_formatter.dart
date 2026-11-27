import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../l10n/app_strings.dart';

class AppErrorFormatter {
  AppErrorFormatter._();

  static const MethodChannel _channel = MethodChannel(
    'com.siteshinn.site_shinn/device_settings',
  );

  static bool isCancelledError(Object error) {
    if (error is GoogleSignInException &&
        error.code == GoogleSignInExceptionCode.canceled) {
      return true;
    }
    if (error is FirebaseAuthException) {
      final code = error.code.toLowerCase();
      return code == 'web-context-canceled' ||
          code == 'canceled-popup-request' ||
          code == 'user-cancelled' ||
          code == 'cancelled';
    }
    return false;
  }

  static bool isOfflineError(Object error) {
    if (error is SocketException || error is TimeoutException) {
      return true;
    }

    if (error is FirebaseAuthException) {
      final code = error.code.toLowerCase();
      if (code == 'network-request-failed' || code == 'timeout') {
        return true;
      }
    }

    if (error is FirebaseException) {
      final code = error.code.toLowerCase();
      if (code == 'unavailable' ||
          code == 'deadline-exceeded' ||
          code == 'network-request-failed') {
        return true;
      }
    }

    final lower = error.toString().toLowerCase();
    return lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('connection closed') ||
        lower.contains('timed out') ||
        lower.contains('timeoutexception') ||
        lower.contains('clientexception') ||
        lower.contains('network-request-failed') ||
        lower.contains('network_error') ||
        lower.contains('network error') ||
        lower.contains('no internet') ||
        lower.contains('unable to resolve host') ||
        lower.contains('unknownhostexception');
  }

  /// Checks actual device network interface state via Android ConnectivityManager
  /// instead of probing `google.com` DNS (which can time out on slow/VPN networks).
  static Future<bool> hasNetworkConnection() async {
    if (kIsWeb) return true;
    try {
      final connected = await _channel.invokeMethod<bool>('isNetworkConnected');
      if (connected != null) return connected;
    } catch (_) {
      // MissingPluginException in pure Dart tests or desktop fallback.
      return true;
    }
    return true;
  }

  static Future<String> formatErrorAsync(
    Object error,
    AppStrings strings,
  ) async {
    if (isCancelledError(error)) {
      return strings.signInCancelled;
    }
    final hasNetwork = await hasNetworkConnection();
    if (!hasNetwork) {
      return strings.offlineNetworkError;
    }
    if (isOfflineError(error)) {
      return strings.serverUnreachableError;
    }
    return formatError(error, strings);
  }

  static String formatError(Object error, AppStrings strings) {
    if (isCancelledError(error)) {
      return strings.signInCancelled;
    }
    if (isOfflineError(error)) {
      return strings.offlineNetworkError;
    }
    if (error is FirebaseException) {
      return error.message ?? error.code;
    }
    if (error is GoogleSignInException) {
      return error.description?.trim().isNotEmpty == true
          ? error.description!.trim()
          : error.code.name;
    }
    return error.toString();
  }
}
