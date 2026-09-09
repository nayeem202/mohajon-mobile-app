import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/constants/app_constants.dart';
import '../../../core/models/product.dart';
import '../../../core/services/download_export_service.dart';
import '../../../core/services/pdf_doc.dart';
import '../../../core/services/pdf_raster_text.dart';
import '../providers/report_providers.dart';

const _invGrey800 = ui.Color(0xFF374151);

class InventoryPdfService {
  final _downloadExportService = DownloadExportService();

  Future<File> saveInventoryReport(
    InventoryReport report,
    DocCompany company,
  ) async {
    if (report.products.isEmpty) {
      throw StateError('No products found to export');
    }
    final fileName = 'inventory-report.pdf';
    final bytes = await buildInventoryPdf(report, company);
    return _saveFile(fileName, bytes);
  }

  Future<Uint8List> buildInventoryPdf(
    InventoryReport report,
    DocCompany company,
  ) async {
    final theme = await buildAppPdfTheme();
    final raster = PdfRasterText();
    final contentWidth = PdfPageFormat.a4.width - 72;
    final colWidths = _colWidths(contentWidth);
    final cellWidths = <double>[for (final w in colWidths) w - 12];

    await _prepareCompany(raster, company);
    for (var i = 0; i < report.products.length; i++) {
      final p = report.products[i];
      await raster.prepare('${i + 1}',
          fontSize: 9, bold: false, color: _invGrey800, width: cellWidths[0]);
      await raster.prepare(p.nameEn.isEmpty ? p.nameBn : p.nameEn,
          fontSize: 9, bold: false, color: _invGrey800, width: cellWidths[1]);
      await raster.prepare(p.category.isEmpty ? 'Uncategorized' : p.category,
          fontSize: 9, bold: false, color: _invGrey800, width: cellWidths[2]);
      await raster.prepare('${p.stockQty}',
          fontSize: 9, bold: false, color: _invGrey800, width: cellWidths[3], textAlign: ui.TextAlign.right);
      await raster.prepare('${p.lowStockAlert}',
          fontSize: 9, bold: false, color: _invGrey800, width: cellWidths[4], textAlign: ui.TextAlign.right);
      await raster.prepare(_fmt(p.stockQty * p.purchasePrice),
          fontSize: 9, bold: false, color: _invGrey800, width: cellWidths[5], textAlign: ui.TextAlign.right);
    }
    final totalStock = report.products.fold<int>(0, (s, p) => s + p.stockQty);
    await raster.prepare('TOTAL',
        fontSize: 9, bold: true, color: _invGrey800, width: cellWidths[0]);
    await raster.prepare('$totalStock',
        fontSize: 9, bold: true, color: _invGrey800, width: cellWidths[3], textAlign: ui.TextAlign.right);
    await raster.prepare(_fmt(report.totalStockValue),
        fontSize: 9, bold: true, color: _invGrey800, width: cellWidths[5], textAlign: ui.TextAlign.right);

    final doc = pw.Document(theme: theme);
    final now = DateTime.now();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) =>
            _header(doc.document, raster, 'Inventory Report', company),
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
            defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
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
                (e) => _productRow(doc.document, raster, cellWidths, e.value, e.key),
              ),
              _totalRow(doc.document, raster, cellWidths, report, totalStock),
            ],
          ),
        ],
      ),
    );
    return doc.save();
  }

  pw.Widget _header(
    PdfDocument pdf,
    PdfRasterText raster,
    String title,
    DocCompany company,
  ) {
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 3,
              child: buildRasterCompanyColumn(pdf, raster, company),
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

  pw.TableRow _productRow(
    PdfDocument pdf,
    PdfRasterText raster,
    List<double> widths,
    Product p,
    int index,
  ) {
    final status = inventoryStatus(p);
    final stockValue = p.stockQty * p.purchasePrice;
    final odd = index.isOdd;
    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: odd ? const PdfColor.fromInt(0xFFF8FAFC) : PdfColors.white,
      ),
      children: [
        _cell(pdf, raster, '${index + 1}', width: widths[0]),
        _cell(pdf, raster, p.nameEn.isEmpty ? p.nameBn : p.nameEn,
            width: widths[1]),
        _cell(pdf, raster,
            p.category.isEmpty ? 'Uncategorized' : p.category,
            width: widths[2]),
        _cell(pdf, raster, '${p.stockQty}',
            width: widths[3],
            alignment: pw.Alignment.centerRight),
        _cell(pdf, raster, '${p.lowStockAlert}',
            width: widths[4],
            alignment: pw.Alignment.centerRight),
        _cell(pdf, raster, _fmt(stockValue),
            width: widths[5],
            alignment: pw.Alignment.centerRight),
        _statusBadge(status),
      ],
    );
  }

  pw.TableRow _totalRow(
    PdfDocument pdf,
    PdfRasterText raster,
    List<double> widths,
    InventoryReport report,
    int totalStock,
  ) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F5F9)),
      children: [
        _cell(pdf, raster, 'TOTAL', width: widths[0], bold: true),
        _cell(pdf, raster, '', width: widths[1], bold: true),
        _cell(pdf, raster, '', width: widths[2], bold: true),
        _cell(pdf, raster, '$totalStock',
            width: widths[3],
            alignment: pw.Alignment.centerRight,
            bold: true),
        _cell(pdf, raster, '', width: widths[4], bold: true),
        _cell(pdf, raster, _fmt(report.totalStockValue),
            width: widths[5],
            alignment: pw.Alignment.centerRight,
            bold: true),
        _cell(pdf, raster, '', width: widths[6], bold: true),
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
    PdfDocument pdf,
    PdfRasterText raster,
    String text, {
    required double width,
    pw.Alignment alignment = pw.Alignment.centerLeft,
    bool bold = false,
    ui.Color? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: raster.build(
        pdf,
        text,
        fontSize: 9,
        bold: bold,
        color: color ?? _invGrey800,
        width: width,
        alignment: alignment,
      ),
    );
  }

  List<double> _colWidths(double contentWidth) {
    const ratios = <double>[1, 2.5, 1.5, 1, 1, 1.5, 1];
    final total = ratios.fold<double>(0, (sum, r) => sum + r);
    return <double>[for (final r in ratios) contentWidth * r / total];
  }

  Future<void> _prepareCompany(PdfRasterText raster, DocCompany company) async {
    const indigo = ui.Color(0xFF1E3A8A);
    const grey600 = ui.Color(0xFF525252);
    const grey500 = ui.Color(0xFF737373);
    await raster.prepare(company.name,
        fontSize: 20, bold: true, color: indigo, width: 300);
    await raster.prepare(company.tagline,
        fontSize: 9, bold: false, color: grey600, width: 300);
    for (final field in <String>[company.address, company.phone, company.email]) {
      if (field.isNotEmpty) {
        await raster.prepare(field,
            fontSize: 8, bold: false, color: grey500, width: 300);
      }
    }
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
              '${AppConstants.appName} — Confidential',
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

  String _fmt(double v) => '৳ ${NumberFormat('#,##0.00').format(v)}';

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
