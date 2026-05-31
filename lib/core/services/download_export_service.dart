import 'dart:io';
import 'dart:typed_data';

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
}
