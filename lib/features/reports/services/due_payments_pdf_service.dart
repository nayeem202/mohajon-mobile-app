import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/services/download_export_service.dart';
import '../../../core/services/server_report_downloader.dart';
import '../models/table_report.dart';
import 'report_table_pdf.dart';

class DuePaymentsPdfService {
  final _downloadExportService = DownloadExportService();
  final _serverDownloader = ServerReportDownloader();

  Future<File> saveDuePayments({
    required ReportTableData table,
    required DateTimeRange range,
  }) async {
    final fileName = 'due-payments-${_rangeFilePart(range)}.pdf';
    final serverBytes = await _serverDownloader.download(
      reportType: 'due-payments',
      format: 'pdf',
      from: range.start,
      to: range.end,
    );
    if (serverBytes != null) return _saveFile(fileName, serverBytes);

    final bytes = await buildTablePdf(table);
    return _saveFile(fileName, bytes);
  }

  Future<File> _saveFile(String fileName, Uint8List bytes) async {
    final androidSavedPath = await _downloadExportService.saveFileToDownloads(
      fileName: fileName,
      mimeType: 'application/pdf',
      bytes: bytes,
    );
    if (androidSavedPath != null) {
      return File(androidSavedPath);
    }

    final directory = await _downloadDirectory();
    try {
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } on FileSystemException {
      final fallback = await getApplicationDocumentsDirectory();
      final file = File('${fallback.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      return file;
    }
  }

  Future<Directory> _downloadDirectory() async {
    if (Platform.isAndroid) {
      final downloads = Directory('/storage/emulated/0/Download');
      if (await downloads.exists()) return downloads;
    }
    return getApplicationDocumentsDirectory();
  }

  String _rangeFilePart(DateTimeRange range) =>
      '${DateFormat('yyyy-MM-dd').format(range.start)}-to-${DateFormat('yyyy-MM-dd').format(range.end)}';
}
