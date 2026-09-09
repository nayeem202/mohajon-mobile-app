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
import '../../expenses/models/expense.dart';

const _expenseOrange = ui.Color(0xFFEA580C);
const _expenseIndigo = ui.Color(0xFF1E3A8A);
const _expenseGrey800 = ui.Color(0xFF374151);

class ExpenseReportPdfService {
  final _downloadExportService = DownloadExportService();

  Future<File> saveExpenseReport({
    required List<Expense> expenses,
    required DateTimeRange range,
    required DocCompany company,
  }) async {
    if (expenses.isEmpty) {
      throw StateError('No data in the selected period');
    }
    final fileName = 'expense-report-${_rangeFilePart(range)}.pdf';
    final bytes = await buildExpenseReportPdf(expenses, range, company);
    return _saveFile(fileName, bytes);
  }

  Future<Uint8List> buildExpenseReportPdf(
    List<Expense> expenses,
    DateTimeRange range,
    DocCompany company,
  ) async {
    final theme = await buildAppPdfTheme();
    final raster = PdfRasterText();
    final contentWidth = PdfPageFormat.a4.width - 72;
    final colWidths = _colWidths(contentWidth);
    final cellWidths = <double>[for (final w in colWidths) w - 12];

    final topCategory = _topCategory(expenses);
    final total = expenses.fold<double>(
      0,
      (sum, expense) => sum + expense.amount,
    );
    await raster.prepare(topCategory,
        fontSize: 9, bold: false, color: _expenseGrey800, width: contentWidth - 20);
    await _prepareCompany(raster, company);
    for (final expense in expenses) {
      await raster.prepare(DateFormat('dd MMM yyyy').format(expense.date),
          fontSize: 9, bold: false, color: _expenseGrey800, width: cellWidths[0]);
      await raster.prepare(expense.categoryLabel,
          fontSize: 9, bold: false, color: _expenseGrey800, width: cellWidths[1]);
      await raster.prepare(expense.description,
          fontSize: 9, bold: false, color: _expenseGrey800, width: cellWidths[2]);
      await raster.prepare(_fmt(expense.amount),
          fontSize: 9,
          bold: true,
          color: _expenseOrange,
          width: cellWidths[3],
          textAlign: ui.TextAlign.right);
    }
    await raster.prepare('TOTAL',
        fontSize: 9, bold: true, color: _expenseGrey800, width: cellWidths[0]);
    await raster.prepare(_fmt(total),
        fontSize: 9,
        bold: true,
        color: _expenseIndigo,
        width: cellWidths[3],
        textAlign: ui.TextAlign.right);

    final doc = pw.Document(theme: theme);
    final average = expenses.isEmpty ? 0.0 : total / expenses.length;
    final categoryCount = expenses
        .map((expense) => expense.categoryId)
        .toSet()
        .length;
    final periodText =
        '${DateFormat('dd MMM yyyy').format(range.start)} - ${DateFormat('dd MMM yyyy').format(range.end)}';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) =>
            _header(doc.document, raster, 'Expense Report', company),
        footer: (context) => _pageFooter(context),
        build: (context) => [
          _reportMetaBar(periodText: periodText, reportType: 'Date Range'),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              _summaryCard(
                'Total Expense',
                _fmt(total),
                const PdfColor.fromInt(0xFFEA580C),
              ),
              pw.SizedBox(width: 10),
              _summaryCard(
                'Entries',
                '${expenses.length}',
                const PdfColor.fromInt(0xFF1E3A8A),
              ),
              pw.SizedBox(width: 10),
              _summaryCard(
                'Average',
                _fmt(average),
                const PdfColor.fromInt(0xFFEA580C),
              ),
              pw.SizedBox(width: 10),
              _summaryCard(
                'Categories',
                '$categoryCount',
                const PdfColor.fromInt(0xFF1E3A8A),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFF8FAFC),
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Row(
              children: [
                pw.Text(
                  'Top Category: ',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: const PdfColor.fromInt(0xFF1E3A8A),
                  ),
                ),
                pw.Text(
                  topCategory,
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
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
              2: pw.FlexColumnWidth(3.2),
              3: pw.FlexColumnWidth(1.4),
            },
            children: [
              _tableHeaderRow([
                'Date',
                'Category',
                'Description',
                'Amount (৳)',
              ]),
              ...expenses.asMap().entries.map(
                (e) => _expenseRow(
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
                  _metaRow('Report Type', 'Expense Report'),
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

  pw.TableRow _expenseRow(
    PdfDocument pdf,
    PdfRasterText raster,
    List<double> widths,
    Expense expense,
    bool odd,
  ) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: odd ? const PdfColor.fromInt(0xFFF8FAFC) : PdfColors.white,
      ),
      children: [
        _cell(pdf, raster, DateFormat('dd MMM yyyy').format(expense.date),
            width: widths[0]),
        _cell(pdf, raster, expense.categoryLabel, width: widths[1]),
        _cell(pdf, raster, expense.description, width: widths[2]),
        _cell(
          pdf,
          raster,
          _fmt(expense.amount),
          width: widths[3],
          alignment: pw.Alignment.centerRight,
          color: _expenseOrange,
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
          color: _expenseIndigo,
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
        color: color ?? _expenseGrey800,
        width: width,
        alignment: alignment,
      ),
    );
  }

  List<double> _colWidths(double contentWidth) {
    const ratios = <double>[1.4, 1.6, 3.2, 1.4];
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

  String _topCategory(List<Expense> expenses) {
    if (expenses.isEmpty) return 'None';
    final amounts = <String, double>{};
    for (final expense in expenses) {
      final key = expense.categoryLabel.isNotEmpty
          ? expense.categoryLabel
          : expense.categoryId;
      amounts[key] = (amounts[key] ?? 0) + expense.amount;
    }
    final entries = amounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.first.key;
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
