import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/constants/app_constants.dart';
import '../../../core/services/pdf_doc.dart';
import '../../../core/services/pdf_raster_text.dart';
import '../models/table_report.dart';

const _ink700 = ui.Color(0xFF374151);
const _gray600 = ui.Color(0xFF525252);
const _white = ui.Color(0xFFFFFFFF);
const _indigo = PdfColor.fromInt(0xFF1E3A8A);
const _cardBg = PdfColor.fromInt(0xFFF8FAFC);

Future<Uint8List> buildTablePdf(
  ReportTableData table,
  DocCompany company,
) async {
  final theme = await buildAppPdfTheme();
  final raster = PdfRasterText();
  final now = DateTime.now();
  final tableWidth = _tableWidth();
  final columnWidths = _columnWidths(table, tableWidth);
  final cellWidths = <double>[
    for (var i = 0; i < table.columns.length; i++) _cellWidth(columnWidths, i),
  ];
  final valueWidth = _summaryValueWidth(table, tableWidth);
  final hasBangla = RegExp(r'[\u0980-\u09FF]').hasMatch(table.title);
  final noData = hasBangla
      ? 'নির্বাচিত সময়ে কোনো তথ্য নেই'
      : 'No data in the selected period';
  final generatedLine =
      '${hasBangla ? 'তৈরির সময়' : 'Generated'}: '
      '${DateFormat('MMM dd, yyyy HH:mm').format(now)}';
  final periodLine = '${hasBangla ? 'সময়কাল' : 'Period'}: ${table.subtitle}';
  final reportTypeLine =
      '${hasBangla ? 'রিপোর্টের ধরন' : 'Report Type'}: ${table.title}';
  final periodBadge = '${hasBangla ? 'সময়কাল' : 'Period'}: ${table.subtitle}';
  final typeBadge =
      '${hasBangla ? 'রিপোর্টের ধরন' : 'Report Type'}: ${table.title}';

  await _prepareCompany(raster, company);
  for (var index = 0; index < table.columns.length; index++) {
    final column = table.columns[index];
    final width = cellWidths[index];
    await raster.prepare(
      column.header,
      fontSize: 9,
      bold: true,
      color: _white,
      width: width,
      textAlign: column.rightAlign ? ui.TextAlign.right : ui.TextAlign.left,
    );
    for (final row in table.rows) {
      await raster.prepare(
        _cellText(row[column.key]),
        fontSize: 9,
        bold: false,
        color: _ink700,
        width: width,
        textAlign: column.rightAlign ? ui.TextAlign.right : ui.TextAlign.left,
      );
    }
  }
  if (table.rows.isEmpty) {
    await raster.prepare(
      noData,
      fontSize: 9,
      bold: false,
      color: _gray600,
      width: tableWidth,
    );
  }
  await raster.prepare(
    table.title,
    fontSize: 14,
    bold: true,
    color: _white,
    width: 200,
    maxLines: 1,
  );
  for (final line in [generatedLine, periodLine, reportTypeLine]) {
    await raster.prepare(
      line,
      fontSize: 8,
      bold: false,
      color: const ui.Color(0xFF525252),
      width: 210,
      maxLines: 1,
    );
  }
  for (final badge in [periodBadge, typeBadge]) {
    await raster.prepare(
      badge,
      fontSize: 9,
      bold: true,
      color: const ui.Color(0xFF1E3A8A),
      width: 240,
      maxLines: 1,
    );
  }
  for (final summary in table.summaries) {
    await raster.prepare(
      summary.label,
      fontSize: 9,
      bold: false,
      color: const ui.Color(0xFF737373),
      width: valueWidth,
      maxLines: 2,
    );
  }
  await raster.prepare(
    noData,
    fontSize: 9,
    bold: false,
    color: _gray600,
    width: tableWidth,
  );
  for (final summary in table.summaries) {
    await raster.prepare(
      summary.value,
      fontSize: 18,
      bold: true,
      color: ui.Color(summary.accent),
      width: valueWidth,
      maxLines: 1,
    );
  }

  final doc = pw.Document(theme: theme);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      header: (context) => _header(doc.document, raster, table, company, now),
      footer: (context) => _pageFooter(context, now),
      build: (context) => [
        _reportMetaBar(doc.document, raster, table, hasBangla),
        pw.SizedBox(height: 16),
        if (table.summaries.isNotEmpty) ...[
          _summaryRow(doc.document, raster, table.summaries, valueWidth),
          pw.SizedBox(height: 20),
        ],
        _dataTable(doc.document, raster, table, cellWidths, noData),
      ],
    ),
  );

  return doc.save();
}

double _summaryValueWidth(ReportTableData table, double tableWidth) {
  final count = table.summaries.length;
  if (count == 0) return 0;
  final cardWidth = (tableWidth - (count - 1) * 10) / count;
  return cardWidth - 24;
}

double _tableWidth() => PdfPageFormat.a4.availableWidth - 72;

double _cellWidth(Map<int, double> widths, int index) =>
    (widths[index] ?? 0) - 12;

Map<int, double> _columnWidths(ReportTableData table, double tableWidth) {
  final totalWeight = table.columns.fold<double>(
    0,
    (sum, column) => sum + column.weight,
  );
  final result = <int, double>{};
  for (var index = 0; index < table.columns.length; index++) {
    result[index] = tableWidth * table.columns[index].weight / totalWeight;
  }
  return result;
}

pw.Widget _header(
  PdfDocument pdf,
  PdfRasterText raster,
  ReportTableData table,
  DocCompany company,
  DateTime now,
) {
  final hasBangla = RegExp(r'[\u0980-\u09FF]').hasMatch(table.title);
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
                    color: _indigo,
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(4),
                    ),
                  ),
                  child: raster.build(
                    pdf,
                    table.title,
                    fontSize: 14,
                    bold: true,
                    color: _white,
                    width: 200,
                    maxLines: 1,
                  ),
                ),
                pw.SizedBox(height: 8),
                _metaRow(
                  pdf,
                  raster,
                  hasBangla ? 'তৈরির সময়' : 'Generated',
                  DateFormat('MMM dd, yyyy HH:mm').format(now),
                ),
                _metaRow(
                  pdf,
                  raster,
                  hasBangla ? 'সময়কাল' : 'Period',
                  table.subtitle,
                ),
                _metaRow(
                  pdf,
                  raster,
                  hasBangla ? 'রিপোর্টের ধরন' : 'Report Type',
                  table.title,
                ),
              ],
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 8),
      pw.Container(
        height: 3,
        decoration: const pw.BoxDecoration(
          color: _indigo,
          borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
        ),
      ),
    ],
  );
}

pw.Widget _metaRow(
  PdfDocument pdf,
  PdfRasterText raster,
  String label,
  String value,
) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: raster.build(
      pdf,
      '$label: $value',
      fontSize: 8,
      bold: false,
      color: const ui.Color(0xFF525252),
      width: 210,
      alignment: pw.Alignment.centerRight,
      maxLines: 1,
    ),
  );
}

pw.Widget _reportMetaBar(
  PdfDocument pdf,
  PdfRasterText raster,
  ReportTableData table,
  bool hasBangla,
) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: pw.BoxDecoration(
      color: _cardBg,
      border: pw.Border.all(color: PdfColors.grey300),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
    ),
    child: pw.Row(
      children: [
        _metaBadge(
          pdf,
          raster,
          hasBangla ? 'সময়কাল' : 'Period',
          table.subtitle,
        ),
        pw.SizedBox(width: 8),
        _metaBadge(
          pdf,
          raster,
          hasBangla ? 'রিপোর্টের ধরন' : 'Report Type',
          table.title,
        ),
      ],
    ),
  );
}

pw.Widget _metaBadge(
  PdfDocument pdf,
  PdfRasterText raster,
  String label,
  String value,
) {
  return pw.Row(
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      raster.build(
        pdf,
        '$label: $value',
        fontSize: 9,
        bold: true,
        color: const ui.Color(0xFF1E3A8A),
        width: 240,
      ),
    ],
  );
}

pw.Widget _summaryRow(
  PdfDocument pdf,
  PdfRasterText raster,
  List<ReportSummary> summaries,
  double valueWidth,
) {
  return pw.Row(
    children: [
      for (var i = 0; i < summaries.length; i++) ...[
        if (i > 0) pw.SizedBox(width: 10),
        pw.Expanded(child: _summaryCard(pdf, raster, summaries[i], valueWidth)),
      ],
    ],
  );
}

pw.Widget _summaryCard(
  PdfDocument pdf,
  PdfRasterText raster,
  ReportSummary summary,
  double valueWidth,
) {
  final accent = PdfColor.fromInt(summary.accent);
  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      border: pw.Border.all(color: PdfColors.grey200),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 22,
          height: 3,
          decoration: pw.BoxDecoration(
            color: accent,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
          ),
        ),
        pw.SizedBox(height: 8),
        raster.build(
          pdf,
          summary.label,
          fontSize: 9,
          bold: false,
          color: const ui.Color(0xFF737373),
          width: valueWidth,
          maxLines: 2,
        ),
        pw.SizedBox(height: 3),
        raster.build(
          pdf,
          summary.value,
          fontSize: 18,
          bold: true,
          color: ui.Color(summary.accent),
          width: valueWidth,
          maxLines: 1,
        ),
      ],
    ),
  );
}

pw.Widget _dataTable(
  PdfDocument pdf,
  PdfRasterText raster,
  ReportTableData table,
  List<double> cellWidths,
  String noData,
) {
  final columnWidths = <int, pw.TableColumnWidth>{
    for (var i = 0; i < table.columns.length; i++)
      i: pw.FixedColumnWidth(cellWidths[i] + 12),
  };
  final border = pw.TableBorder(
    horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
    bottom: pw.BorderSide(color: PdfColors.grey600, width: 0.5),
    top: pw.BorderSide(color: PdfColors.grey600, width: 0.5),
  );

  final headerRow = pw.TableRow(
    decoration: const pw.BoxDecoration(color: _indigo),
    children: [
      for (var index = 0; index < table.columns.length; index++)
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: _headerCell(
            pdf,
            raster,
            table.columns[index],
            cellWidths[index],
          ),
        ),
    ],
  );

  if (table.rows.isEmpty) {
    final width = cellWidths.fold<double>(0, (sum, w) => sum + w + 12);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Table(
          defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
          columnWidths: columnWidths,
          border: border,
          children: [headerRow],
        ),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          decoration: pw.BoxDecoration(
            color: _cardBg,
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.grey600, width: 0.5),
            ),
          ),
          child: raster.build(
            pdf,
            noData,
            fontSize: 9,
            bold: false,
            color: _gray600,
            width: width,
            alignment: pw.Alignment.centerLeft,
          ),
        ),
      ],
    );
  }

  return pw.Table(
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
    columnWidths: columnWidths,
    border: border,
    children: [
      headerRow,
      for (var r = 0; r < table.rows.length; r++)
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: r.isOdd ? _cardBg : PdfColors.white,
          ),
          children: [
            for (var index = 0; index < table.columns.length; index++)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 7,
                ),
                child: _dataCell(
                  pdf,
                  raster,
                  _cellText(table.rows[r][table.columns[index].key]),
                  table.columns[index].rightAlign,
                  cellWidths[index],
                ),
              ),
          ],
        ),
    ],
  );
}

pw.Widget _headerCell(
  PdfDocument pdf,
  PdfRasterText raster,
  ReportTableColumn column,
  double width,
) {
  return raster.build(
    pdf,
    column.header,
    fontSize: 9,
    bold: true,
    color: _white,
    width: width,
    alignment: column.rightAlign
        ? pw.Alignment.centerRight
        : pw.Alignment.centerLeft,
  );
}

pw.Widget _dataCell(
  PdfDocument pdf,
  PdfRasterText raster,
  String text,
  bool rightAlign,
  double width,
) {
  return raster.build(
    pdf,
    text,
    fontSize: 9,
    bold: false,
    color: _ink700,
    width: width,
    alignment: rightAlign ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
  );
}

String _cellText(Object? value) {
  if (value == null) return '';
  if (value is num) return NumberFormat('#,##0.00').format(value);
  if (value is DateTime) return DateFormat('dd MMM yyyy').format(value);
  return value.toString();
}

Future<void> _prepareCompany(PdfRasterText raster, DocCompany company) async {
  const indigo = ui.Color(0xFF1E3A8A);
  const grey600 = ui.Color(0xFF525252);
  const grey500 = ui.Color(0xFF737373);
  await raster.prepare(
    company.name,
    fontSize: 20,
    bold: true,
    color: indigo,
    width: 300,
  );
  await raster.prepare(
    company.tagline,
    fontSize: 9,
    bold: false,
    color: grey600,
    width: 300,
  );
  for (final field in <String>[company.address, company.phone, company.email]) {
    if (field.isNotEmpty) {
      await raster.prepare(
        field,
        fontSize: 8,
        bold: false,
        color: grey500,
        width: 300,
      );
    }
  }
}

pw.Widget _pageFooter(pw.Context context, DateTime now) {
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
        'Generated on ${DateFormat('MMM dd, yyyy HH:mm').format(now)}',
        style: pw.TextStyle(fontSize: 7, color: PdfColors.grey400),
      ),
    ],
  );
}
