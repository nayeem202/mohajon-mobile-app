import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/download_export_service.dart';
import '../../../core/services/pdf_doc.dart';
import '../../../core/services/pdf_raster_text.dart';
import '../models/daily_sales.dart';

const _salesOrange = ui.Color(0xFFEA580C);
const _salesIndigo = ui.Color(0xFF1E3A8A);
const _salesGrey800 = ui.Color(0xFF374151);

class SalesSummaryPdfService {
  final _downloadExportService = DownloadExportService();

  Future<File> saveSalesSummary({
    required List<DailySales> days,
    required DateTimeRange range,
    required DocCompany company,
  }) async {
    if (days.isEmpty) {
      throw StateError('No data in the selected period');
    }
    final fileName = 'sales-summary-${_rangeFilePart(range)}.pdf';
    final bytes = await buildSalesSummaryPdf(days, range, company);
    return _saveFile(fileName, bytes);
  }

  Future<Uint8List> buildSalesSummaryPdf(
    List<DailySales> days,
    DateTimeRange range,
    DocCompany company,
  ) async {
    final theme = await buildAppPdfTheme();
    final raster = PdfRasterText();
    final contentWidth = PdfPageFormat.a4.width - 72;
    final colWidths = _colWidths(contentWidth);
    final cellWidths = <double>[for (final w in colWidths) w - 12];

    final total = days.fold<double>(0, (sum, day) => sum + day.amount);
    final transactions = days.fold<int>(
      0,
      (sum, day) => sum + day.transactionCount,
    );
    final average = transactions > 0 ? total / transactions : 0.0;
    await _prepareCompany(raster, company);
    for (final day in days) {
      await raster.prepare(DateFormat('dd MMM yyyy').format(day.date),
          fontSize: 9, bold: false, color: _salesGrey800, width: cellWidths[0]);
      await raster.prepare('${day.transactionCount}',
          fontSize: 9, bold: false, color: _salesGrey800, width: cellWidths[1]);
      await raster.prepare(_fmt(day.average),
          fontSize: 9, bold: false, color: _salesGrey800, width: cellWidths[2]);
      await raster.prepare(_fmt(day.amount),
          fontSize: 9, bold: true, color: _salesOrange, width: cellWidths[3], textAlign: ui.TextAlign.right);
    }
    await raster.prepare('TOTAL',
        fontSize: 9, bold: true, color: _salesGrey800, width: cellWidths[0]);
    await raster.prepare(_fmt(total),
        fontSize: 9, bold: true, color: _salesIndigo, width: cellWidths[3], textAlign: ui.TextAlign.right);

    final doc = pw.Document(theme: theme);
    final periodText =
        '${DateFormat('dd MMM yyyy').format(range.start)} - ${DateFormat('dd MMM yyyy').format(range.end)}';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) =>
            _header(
              doc.document,
              raster,
              'Sales Summary',
              company: company,
              periodText: periodText,
            ),
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
                (e) => _dailyRow(
                  doc.document,
                  raster,
                  cellWidths,
                  e.value,
                  e.key.isOdd,
                ),
              ),
              _totalRow(doc.document, raster, cellWidths, total),
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
    String title, {
    required String periodText,
    required DocCompany company,
  }) {
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

  pw.TableRow _dailyRow(
    PdfDocument pdf,
    PdfRasterText raster,
    List<double> widths,
    DailySales day,
    bool odd,
  ) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: odd ? const PdfColor.fromInt(0xFFF8FAFC) : PdfColors.white,
      ),
      children: [
        _cell(pdf, raster, DateFormat('dd MMM yyyy').format(day.date),
            width: widths[0]),
        _cell(pdf, raster, '${day.transactionCount}', width: widths[1]),
        _cell(pdf, raster, _fmt(day.average), width: widths[2]),
        _cell(
          pdf,
          raster,
          _fmt(day.amount),
          width: widths[3],
          alignment: pw.Alignment.centerRight,
          color: _salesOrange,
          bold: true,
        ),
      ],
    );
  }

  pw.TableRow _totalRow(
    PdfDocument pdf,
    PdfRasterText raster,
    List<double> widths,
    double total,
  ) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F5F9)),
      children: [
        _cell(pdf, raster, 'TOTAL', width: widths[0], bold: true),
        _cell(pdf, raster, '', width: widths[1]),
        _cell(pdf, raster, '', width: widths[2]),
        _cell(
          pdf,
          raster,
          _fmt(total),
          width: widths[3],
          alignment: pw.Alignment.centerRight,
          color: _salesIndigo,
          bold: true,
        ),
      ],
    );
  }

  pw.Widget _cell(
    PdfDocument pdf,
    PdfRasterText raster,
    String value, {
    required double width,
    pw.Alignment alignment = pw.Alignment.centerLeft,
    ui.Color? color,
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: raster.build(
        pdf,
        value,
        fontSize: 9,
        bold: bold,
        color: color ?? _salesGrey800,
        width: width,
        alignment: alignment,
      ),
    );
  }

  List<double> _colWidths(double contentWidth) {
    const ratios = <double>[1.4, 1.6, 1.6, 1.4];
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
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        'Page ${context.pageNumber} of ${context.pagesCount}',
        style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
      ),
    );
  }

  String _fmt(double v) => '৳ ${NumberFormat('#,##0.00').format(v)}';

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
