import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_strings.dart';
import '../../services/app_update_service.dart';

class AppUpdateDialog extends StatefulWidget {
  final AppUpdateInfo info;
  final AppStrings strings;

  const AppUpdateDialog({
    super.key,
    required this.info,
    required this.strings,
  });

  static Future<void> show(
    BuildContext context, {
    required AppUpdateInfo info,
    required AppStrings strings,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !info.forceUpdate,
      builder: (_) => AppUpdateDialog(info: info, strings: strings),
    );
  }

  static Future<void> maybeCheckOnStartup(
    BuildContext context, {
    required AppStrings strings,
  }) async {
    final info = await AppUpdateService.instance.checkForUpdate(
      isBurmese: strings.isBurmese,
      startupOnlyOnce: true,
    );
    if (info != null && context.mounted) {
      await show(context, info: info, strings: strings);
    }
  }

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  bool _isDownloading = false;
  double? _progress;
  int _receivedBytes = 0;
  int _totalBytes = -1;
  String? _statusMessage;

  String _formatMb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

  Future<void> _startUpdate() async {
    final strings = widget.strings;
    setState(() {
      _isDownloading = true;
      _progress = null;
      _receivedBytes = 0;
      _totalBytes = -1;
      _statusMessage = null;
    });

    try {
      final result = await AppUpdateService.instance.downloadAndInstallApk(
        widget.info,
        onProgress: (progress, received, total) {
          if (!mounted) return;
          setState(() {
            _progress = progress;
            _receivedBytes = received;
            _totalBytes = total;
          });
        },
      );

      if (!mounted) return;
      if (result == 'needs_permission') {
        setState(() {
          _isDownloading = false;
          _statusMessage = strings.allowInstallUnknownApps;
        });
      } else if (result == 'launched') {
        setState(() => _isDownloading = false);
        if (!widget.info.forceUpdate && mounted) {
          Navigator.of(context).pop();
        }
      } else {
        setState(() {
          _isDownloading = false;
          _statusMessage = strings.updateFailed;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusMessage = strings.updateFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    final info = widget.info;
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !info.forceUpdate && !_isDownloading,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.system_update_rounded, color: colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(strings.updateAvailableTitle)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                strings.updateVersionRow(
                  info.currentVersion,
                  info.latestVersion,
                ),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (info.releaseNotes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  strings.releaseNotesLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(info.releaseNotes),
                ),
              ],
              if (_isDownloading) ...[
                const SizedBox(height: 14),
                Text(
                  _totalBytes > 0
                      ? '${strings.downloadingUpdate} (${_formatMb(_receivedBytes)} / ${_formatMb(_totalBytes)} MB)'
                      : strings.downloadingUpdate,
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: _progress),
              ],
              if (_statusMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _statusMessage!,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (!info.forceUpdate && !_isDownloading)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(strings.laterBtn),
            ),
          if (_statusMessage != null && !_isDownloading)
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: info.apkUrl));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(info.apkUrl)),
                  );
                }
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy Link'),
            ),
          FilledButton.icon(
            onPressed: _isDownloading ? null : _startUpdate,
            icon: _isDownloading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded, size: 18),
            label: Text(strings.updateNowBtn),
          ),
        ],
      ),
    );
  }
}
