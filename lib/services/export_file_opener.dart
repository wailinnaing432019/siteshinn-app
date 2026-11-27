import 'package:flutter/services.dart';

class SavedExportResult {
  final String uriOrPath;
  final String? localFallbackPath;
  final String mimeType;
  final String fileName;

  const SavedExportResult({
    required this.uriOrPath,
    this.localFallbackPath,
    required this.mimeType,
    required this.fileName,
  });
}

class ExportFileOpener {
  ExportFileOpener._();

  static const MethodChannel _channel = MethodChannel(
    'com.siteshinn.site_shinn/device_settings',
  );

  static Future<bool> open(SavedExportResult saved) async {
    try {
      final opened = await _channel.invokeMethod<bool>('openExportedFile', {
        'uri': saved.uriOrPath,
        'fallbackPath': saved.localFallbackPath,
        'mimeType': saved.mimeType,
      });
      return opened ?? false;
    } catch (_) {
      return false;
    }
  }
}
