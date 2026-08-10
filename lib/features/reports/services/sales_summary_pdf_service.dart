import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/download_export_service.dart';
import '../../../core/services/server_report_downloader.dart';
import '../models/daily_sales.dart';

class SalesSummaryPdfService {
  final _downloadExportService = DownloadExportService();
  final _serverDownloader = ServerReportDownloader();
  pw.Font? _baseFont;
  pw.Font? _boldFont;

  Future<pw.ThemeData> _buildTheme() async {
    if (_baseFont == null) {
      final regular = await rootBundle.load(
        'assets/fonts/NotoSansBengali-Regular.ttf',
      );
      _baseFont = pw.Font.ttf(regular);
    }
    if (_boldFont == null) {
      final bold = await rootBundle.load(
        'assets/fonts/NotoSansBengali-Bold.ttf',
      );
      _boldFont = pw.Font.ttf(bold);
    }
    return pw.ThemeData.withFont(base: _baseFont!, bold: _boldFont!);
  }

  Future<File> saveSalesSummary({
    required List<DailySales> days,
    required DateTimeRange range,
  }) async {
    final fileName = 'sales-summary-${_rangeFilePart(range)}.pdf';
    final serverBytes = await _serverDownloader.download(
      reportType: 'sales',
      format: 'pdf',
      from: range.start,
      to: range.end,
    );
    if (serverBytes != null) return _saveFile(fileName, serverBytes);

    final bytes = await buildSalesSummaryPdf(days, range);
    return _saveFile(fileName, bytes);
  }

  Future<Uint8List> buildSalesSummaryPdf(
    List<DailySales> days,
    DateTimeRange range,
  ) async {
    final theme = await _buildTheme();
    final doc = pw.Document(theme: theme);
    final total = days.fold<double>(0, (sum, day) => sum + day.amount);
    final transactions = days.fold<int>(
      0,
      (sum, day) => sum + day.transactionCount,
    );
    final average = transactions > 0 ? total / transactions : 0.0;
    final periodText =
        '${DateFormat('dd MMM yyyy').format(range.start)} - ${DateFormat('dd MMM yyyy').format(range.end)}';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => _header('Sales Summary', periodText: periodText),
        footer: (context) => _pageFooter(context),
        build: (context) => [
          _reportMetaBar(periodText: periodText, reportType: 'Date Range'),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              _summaryCard(
                'Total Sales',
                _fmt(total),
                const PdfColor.fromInt(0xFFEA580C),
              ),
              pw.SizedBox(width: 10),
              _summaryCard(
                'Transactions',
                '$transactions',
                const PdfColor.fromInt(0xFF1E3A8A),
              ),
              pw.SizedBox(width: 10),
              _summaryCard(
                'Average Order',
                _fmt(average),
                const PdfColor.fromInt(0xFFEA580C),
              ),
              pw.SizedBox(width: 10),
              _summaryCard(
                'Days',
                '${days.length}',
                const PdfColor.fromInt(0xFF1E3A8A),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Table(
            border: pw.TableBorder(
              horizontalInside: pw.BorderSide(
                color: PdfColors.grey300,
                width: 0.5,
              ),
              bottom: pw.BorderSide(color: PdfColors.grey600, width: 0.5),
              top: pw.BorderSide(color: PdfColors.grey600, width: 0.5),
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.4),
              1: pw.FlexColumnWidth(1.6),
              2: pw.FlexColumnWidth(1.6),
              3: pw.FlexColumnWidth(1.4),
            },
            children: [
              _tableHeaderRow([
                'Date',
                'Transactions',
                'Average Order',
                'Amount (৳)',
              ]),
              ...days.asMap().entries.map(
                (e) => _dailyRow(e.value, e.key.isOdd),
              ),
              _totalRow(total),
            ],
          ),
        ],
      ),
    );
    return doc.save();
  }

  pw.Widget _header(String title, {required String periodText}) {
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 3,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.fromLTRB(0, 0, 0, 4),
                    child: pw.Text(
                      'Haalkhata',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: const PdfColor.fromInt(0xFF1E3A8A),
                      ),
                    ),
                  ),
                  pw.Text(
                    'Smart POS & Inventory Management',
                    style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Dhaka, Bangladesh',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                  ),
                  pw.Text(
                    '+880 1700-000000',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                  ),
                  pw.Text(
                    'hello@haalkhata.com',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                  ),
                ],
              ),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: pw.BoxDecoration(
                      color: const PdfColor.fromInt(0xFF1E3A8A),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(4),
                      ),
                    ),
                    child: pw.Text(
                      title,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  _metaRow(
                    'Generated',
                    DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now()),
                  ),
                  _metaRow('Period', periodText),
                  _metaRow('Report Type', 'Sales Summary'),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          height: 3,
          decoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xFF1E3A8A),
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
          ),
        ),
      ],
    );
  }

  pw.Widget _reportMetaBar({
    required String periodText,
    required String reportType,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF8FAFC),
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Row(
              children: [
                _metaBadge('Period', periodText),
                pw.SizedBox(width: 16),
                _metaBadge('Report Type', reportType),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _metaRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.RichText(
        textAlign: pw.TextAlign.end,
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$label: ',
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
            pw.TextSpan(
              text: value,
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _metaBadge(String label, String value) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(
          '$label: ',
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: const PdfColor.fromInt(0xFF1E3A8A),
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      ],
    );
  }

  pw.Widget _summaryCard(String label, String value, PdfColor accent) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          border: pw.Border.all(color: PdfColors.grey200),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 24,
              height: 3,
              decoration: pw.BoxDecoration(
                color: accent,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              label,
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.TableRow _tableHeaderRow(List<String> headers) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1E3A8A)),
      children: headers
          .map(
            (header) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 8,
              ),
              child: pw.Text(
                header,
                textAlign: header == 'Amount (৳)'
                    ? pw.TextAlign.center
                    : pw.TextAlign.left,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  pw.TableRow _dailyRow(DailySales day, bool odd) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: odd ? const PdfColor.fromInt(0xFFF8FAFC) : PdfColors.white,
      ),
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: pw.Text(
            DateFormat('dd MMM yyyy').format(day.date),
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: pw.Text(
            '${day.transactionCount}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: pw.Text(
            _fmt(day.average),
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: pw.Text(
            _fmt(day.amount),
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              fontSize: 9,
              color: const PdfColor.fromInt(0xFFEA580C),
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  pw.TableRow _totalRow(double total) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F5F9)),
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: pw.Text(
            'TOTAL',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: pw.Text(''),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: pw.Text(''),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: pw.Text(
            _fmt(total),
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF1E3A8A),
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _pageFooter(pw.Context context) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        'Page ${context.pageNumber} of ${context.pagesCount}',
        style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
      ),
    );
  }

  String _fmt(double v) => '৳ ${NumberFormat('#,##0').format(v)}';

  String _rangeFilePart(DateTimeRange range) =>
      '${DateFormat('yyyy-MM-dd').format(range.start)}-to-${DateFormat('yyyy-MM-dd').format(range.end)}';

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
}
