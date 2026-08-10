import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/models/product.dart';
import '../../../core/services/download_export_service.dart';
import '../../../core/services/server_report_downloader.dart';
import '../providers/report_providers.dart';

class InventoryPdfService {
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

  Future<File> saveInventoryReport(InventoryReport report) async {
    final fileName = 'inventory-report.pdf';
    final serverBytes = await _serverDownloader.download(
      reportType: 'inventory',
      format: 'pdf',
    );
    if (serverBytes != null) return _saveFile(fileName, serverBytes);

    final bytes = await buildInventoryPdf(report);
    return _saveFile(fileName, bytes);
  }

  Future<Uint8List> buildInventoryPdf(InventoryReport report) async {
    final theme = await _buildTheme();
    final doc = pw.Document(theme: theme);
    final now = DateTime.now();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => _header('Inventory Report'),
        footer: (context) => _pageFooter(context),
        build: (context) => [
          _reportMetaBar(now, report: report),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              _summaryCard(
                'Total Items',
                '${report.totalItems}',
                const PdfColor.fromInt(0xFF1E3A8A),
              ),
              pw.SizedBox(width: 10),
              _summaryCard(
                'Stock Value',
                _fmt(report.totalStockValue),
                const PdfColor.fromInt(0xFFEA580C),
              ),
              pw.SizedBox(width: 10),
              _summaryCard(
                'Low Stock',
                '${report.lowStockCount}',
                const PdfColor.fromInt(0xFFD97706),
              ),
              pw.SizedBox(width: 10),
              _summaryCard(
                'Out of Stock',
                '${report.outOfStockCount}',
                const PdfColor.fromInt(0xFFDC2626),
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
              0: pw.FlexColumnWidth(1),
              1: pw.FlexColumnWidth(2.5),
              2: pw.FlexColumnWidth(1.5),
              3: pw.FlexColumnWidth(1),
              4: pw.FlexColumnWidth(1),
              5: pw.FlexColumnWidth(1.5),
              6: pw.FlexColumnWidth(1),
            },
            children: [
              _tableHeaderRow([
                '#',
                'Product Name',
                'Category',
                'Stock',
                'Alert',
                'Stock Value',
                'Status',
              ]),
              ...report.products.asMap().entries.map(
                (e) => _productRow(e.value, e.key),
              ),
              _totalRow(report),
            ],
          ),
        ],
      ),
    );
    return doc.save();
  }

  pw.Widget _header(String title) {
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
                  _metaRow(
                    'Period',
                    'As of ${DateFormat('MMMM d, yyyy').format(DateTime.now())}',
                  ),
                  _metaRow('Report Type', 'Inventory Report'),
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

  pw.Widget _reportMetaBar(DateTime now, {InventoryReport? report}) {
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
                _metaBadge(
                  'Period',
                  'As of ${DateFormat('MMMM d, yyyy').format(now)}',
                ),
                pw.SizedBox(width: 16),
                _metaBadge('Report Type', 'Inventory Report'),
                pw.SizedBox(width: 16),
                _metaBadge('Total Products', '${report?.products.length ?? 0}'),
              ],
            ),
          ),
        ],
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
            (h) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 8,
              ),
              child: pw.Text(
                h,
                textAlign:
                    h == '#' ||
                        h == 'Stock' ||
                        h == 'Alert' ||
                        h == 'Stock Value' ||
                        h == 'Status'
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

  pw.TableRow _productRow(Product p, int index) {
    final status = inventoryStatus(p);
    final statusLabel = status == InventoryStatus.outOfStock
        ? 'Out of Stock'
        : status == InventoryStatus.low
        ? 'Low'
        : 'Normal';
    final stockValue = p.stockQty * p.purchasePrice;
    final odd = index.isOdd;
    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: odd ? const PdfColor.fromInt(0xFFF8FAFC) : PdfColors.white,
      ),
      children: [
        _cell('${index + 1}'),
        _cell(p.nameEn.isEmpty ? p.nameBn : p.nameEn),
        _cell(p.category.isEmpty ? 'Uncategorized' : p.category),
        _cell('${p.stockQty}', align: pw.TextAlign.right),
        _cell('${p.lowStockAlert}', align: pw.TextAlign.right),
        _cell(_fmt(stockValue), align: pw.TextAlign.right),
        _statusBadge(status),
      ],
    );
  }

  pw.TableRow _totalRow(InventoryReport report) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F5F9)),
      children: [
        _cell('TOTAL', bold: true),
        _cell('', bold: true),
        _cell('', bold: true),
        _cell(
          '${report.products.fold<int>(0, (s, p) => s + p.stockQty)}',
          align: pw.TextAlign.right,
          bold: true,
        ),
        _cell('', bold: true),
        _cell(
          _fmt(report.totalStockValue),
          align: pw.TextAlign.right,
          bold: true,
        ),
        _cell('', bold: true),
      ],
    );
  }

  pw.Widget _statusBadge(InventoryStatus status) {
    final bg = status == InventoryStatus.normal
        ? const PdfColor.fromInt(0xFFDCFCE7)
        : status == InventoryStatus.low
        ? const PdfColor.fromInt(0xFFFEF3C7)
        : const PdfColor.fromInt(0xFFFEE2E2);
    final fg = status == InventoryStatus.normal
        ? const PdfColor.fromInt(0xFF16A34A)
        : status == InventoryStatus.low
        ? const PdfColor.fromInt(0xFFD97706)
        : const PdfColor.fromInt(0xFFDC2626);
    final label = status == InventoryStatus.normal
        ? 'Normal'
        : status == InventoryStatus.low
        ? 'Low'
        : 'Out';
    return pw.Center(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: pw.BoxDecoration(
          color: bg,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
        ),
        child: pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: fg,
          ),
        ),
      ),
    );
  }

  pw.Widget _cell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    bool bold = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? PdfColors.grey800,
        ),
      ),
    );
  }

  pw.Widget _pageFooter(pw.Context context) {
    return pw.Column(
      children: [
        pw.Divider(thickness: 0.5, color: PdfColors.grey300),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Haalkhata — Confidential',
              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
            ),
          ],
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'Generated on ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}',
          style: pw.TextStyle(fontSize: 7, color: PdfColors.grey400),
        ),
      ],
    );
  }

  String _fmt(double v) => '৳ ${NumberFormat('#,##0').format(v)}';

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
      final d = Directory('/storage/emulated/0/Download');
      if (await d.exists()) return d;
    }
    return getApplicationDocumentsDirectory();
  }
}
