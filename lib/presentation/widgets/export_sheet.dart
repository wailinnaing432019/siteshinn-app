import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';

Future<void> showExportOptionsSheet({
  required BuildContext context,
  required AppStrings strings,
  required String title,
  required Future<void> Function() onShare,
  required Future<bool> Function() onSaveToDevice,
}) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                '$title • ${strings.chooseExportAction}',
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: Text(strings.shareFile),
              subtitle: Text(strings.shareFileSubtitle),
              onTap: () => Navigator.of(ctx).pop('share'),
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: Text(strings.saveToDevice),
              subtitle: Text(strings.saveToDeviceSubtitle),
              onTap: () => Navigator.of(ctx).pop('save'),
            ),
          ],
        ),
      ),
    ),
  );

  if (!context.mounted || action == null) return;

  try {
    if (action == 'share') {
      await onShare();
    } else if (action == 'save') {
      final saved = await onSaveToDevice();
      if (saved && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.savedToDeviceToast)),
        );
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${strings.exportFailed}: $e')),
      );
    }
  }
}
