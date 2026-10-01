import 'dart:io';

import 'package:flutter/services.dart';

class DownloadExportService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.inventory_1/downloads',
  );

  Future<String?> saveFileToDownloads({
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    if (!Platform.isAndroid) return null;

    final savedPath = await _channel.invokeMethod<String>('saveFileToDownloads', {
      'fileName': fileName,
      'mimeType': mimeType,
      'bytes': bytes,
    });
    return savedPath;
  }

  Future<Map<String, dynamic>?> pickBackupFile() async {
    if (!Platform.isAndroid) return null;
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('pickBackupFile');
    if (result == null) return null;
    return {
      'fileName': result['fileName']?.toString() ?? 'backup.json',
      'bytes': result['bytes'],
    };
  }
}
