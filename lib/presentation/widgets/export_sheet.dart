import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../services/export_file_opener.dart';

Future<void> showExportOptionsSheet({
  required BuildContext context,
  required AppStrings strings,
  required String title,
  required Future<void> Function() onShare,
  required Future<SavedExportResult?> Function() onSaveToDevice,
}) async {
  final messenger = ScaffoldMessenger.of(context);
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

  if (action == null) return;

  try {
    if (action == 'share') {
      await onShare().timeout(const Duration(seconds: 30));
    } else if (action == 'save') {
      final saved = await onSaveToDevice();
      if (saved != null) {
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 8),
            content: Text('${strings.savedToDeviceToast} (${saved.fileName})'),
            action: SnackBarAction(
              label: strings.openBtn,
              onPressed: () async {
                final ok = await ExportFileOpener.open(saved);
                if (!ok) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(strings.noAppToOpenFile)),
                  );
                }
              },
            ),
          ),
        );
      }
    }
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('${strings.exportFailed}: $e')),
    );
  }
}
