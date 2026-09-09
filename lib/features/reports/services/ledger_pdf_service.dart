import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/constants/app_constants.dart';
import '../../../core/services/download_export_service.dart';
import '../../../core/services/pdf_doc.dart';
import '../../../core/services/pdf_raster_text.dart';
import '../models/customer_ledger.dart';
import '../models/ledger_entry.dart';

const _ledgerIndigo = ui.Color(0xFF1E3A8A);
const _ledgerRed = ui.Color(0xFFDC2626);
const _ledgerAmber = ui.Color(0xFFD97706);
const _ledgerGrey700 = ui.Color(0xFF374151);

class LedgerPdfService {
  final _downloadExportService = DownloadExportService();

  Future<File> saveAllCustomers(
    List<CustomerLedger> customers,
    DocCompany company,
  ) async {
    if (customers.isEmpty) {
      throw StateError('No data in the selected period');
    }
    final fileName = 'customer-ledger-all.pdf';
    final bytes = await buildAllCustomersPdf(customers, company);
    return _saveFile(fileName, bytes);
  }

  Future<File> saveCustomerDetail(
    CustomerLedger customer,
    List<LedgerEntry> entries,
    DocCompany company,
  ) async {
    if (entries.isEmpty) {
      throw StateError('No ledger entries for this customer');
    }
    final fileName =
        'ledger-${_safeFilePart(customer.name.isEmpty ? 'customer' : customer.name)}.pdf';
    final bytes = await buildCustomerDetailPdf(customer, entries, company);
    return _saveFile(fileName, bytes);
  }

  Future<Uint8List> buildAllCustomersPdf(
    List<CustomerLedger> customers,
    DocCompany company,
  ) async {
    final theme = await buildAppPdfTheme();
    final doc = pw.Document(theme: theme);
    final raster = PdfRasterText();
    final contentWidth = PdfPageFormat.a4.width - 72;
    final cellWidths = _cellWidths(contentWidth, const [2.5, 2, 1.5, 1.5, 1.5, 1.2]);
    final totalOutstanding = customers.fold<double>(0, (s, c) => s + c.balance);
    final withDues = customers.where((c) => c.hasDue).length;
    final now = DateTime.now();
    await _prepareCompany(raster, company);
    for (final c in customers) {
      await raster.prepare(c.name,
          fontSize: 9, bold: false, color: _ledgerGrey700, width: cellWidths[0]);
      await raster.prepare(c.phone,
          fontSize: 9, bold: false, color: _ledgerGrey700, width: cellWidths[1]);
      await raster.prepare(_fmt(c.debit),
          fontSize: 9, bold: false, color: _ledgerGrey700, width: cellWidths[2], textAlign: ui.TextAlign.right);
      await raster.prepare(_fmt(c.credit),
          fontSize: 9, bold: false, color: _ledgerGrey700, width: cellWidths[3], textAlign: ui.TextAlign.right);
      await raster.prepare(_fmt(c.balance),
          fontSize: 9,
          bold: c.status == LedgerStatus.due,
          color: _balanceColor(c.status),
          width: cellWidths[4],
          textAlign: ui.TextAlign.right);
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) =>
            _header(doc.document, raster, 'Customer Ledger', company: company),
        footer: (context) => _pageFooter(context),
        build: (context) => [
          _reportMetaBar(now),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              _summaryCard(
                'Total Customers',
                '${customers.length}',
                const PdfColor.fromInt(0xFF1E3A8A),
              ),
              pw.SizedBox(width: 10),
              _summaryCard(
                'Total Outstanding',
                _fmt(totalOutstanding),
                const PdfColor.fromInt(0xFFEA580C),
              ),
              pw.SizedBox(width: 10),
              _summaryCard(
                'Customers With Dues',
                '$withDues',
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
              0: pw.FlexColumnWidth(2.5),
              1: pw.FlexColumnWidth(2),
              2: pw.FlexColumnWidth(1.5),
              3: pw.FlexColumnWidth(1.5),
              4: pw.FlexColumnWidth(1.5),
              5: pw.FlexColumnWidth(1.2),
            },
            children: [
              _tableHeaderRow([
                'Customer Name',
                'Phone Number',
                'Debit (DR)',
                'Credit (CR)',
                'Closing Balance',
                'Status',
              ]),
              ...customers.asMap().entries.map(
                (e) => _customerRow(
                  doc.document,
                  raster,
                  cellWidths,
                  e.value,
                  e.key.isOdd,
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return doc.save();
  }

  Future<Uint8List> buildCustomerDetailPdf(
    CustomerLedger customer,
    List<LedgerEntry> entries,
    DocCompany company,
  ) async {
    final theme = await buildAppPdfTheme();
    final doc = pw.Document(theme: theme);
    final raster = PdfRasterText();
    final contentWidth = PdfPageFormat.a4.width - 72;
    final cellWidths = _cellWidths(contentWidth, const [1.5, 3, 1.3, 1.3, 1.3]);
    final totalDebit = entries.fold<double>(0, (s, e) => s + e.debit);
    final totalCredit = entries.fold<double>(0, (s, e) => s + e.credit);
    final lastBalance = entries.isEmpty ? 0.0 : entries.last.balance;
    final now = DateTime.now();
    await _prepareCompany(raster, company);
    await raster.prepare(customer.name,
        fontSize: 14, bold: true, color: _ledgerIndigo, width: contentWidth - 24);
    await raster.prepare(customer.phone,
        fontSize: 9, bold: false, color: _ledgerGrey700, width: contentWidth - 24);
    for (final e in entries) {
      await raster.prepare(DateFormat('MMM d, y').format(e.date),
          fontSize: 9, bold: false, color: _ledgerGrey700, width: cellWidths[0]);
      await raster.prepare(e.particulars,
          fontSize: 9, bold: false, color: _ledgerGrey700, width: cellWidths[1]);
      await raster.prepare(e.debit > 0 ? _fmt(e.debit) : '',
          fontSize: 9, bold: false, color: _ledgerGrey700, width: cellWidths[2], textAlign: ui.TextAlign.right);
      await raster.prepare(e.credit > 0 ? _fmt(e.credit) : '',
          fontSize: 9, bold: false, color: _ledgerGrey700, width: cellWidths[3], textAlign: ui.TextAlign.right);
      await raster.prepare(_fmt(e.balance),
          fontSize: 9,
          bold: e.balance != 0,
          color: e.balance != 0 ? _ledgerRed : _ledgerGrey700,
          width: cellWidths[4],
          textAlign: ui.TextAlign.right);
    }
    await raster.prepare('TOTAL',
        fontSize: 9, bold: true, color: _ledgerIndigo, width: cellWidths[0]);
    await raster.prepare(_fmt(totalDebit),
        fontSize: 9, bold: true, color: _ledgerIndigo, width: cellWidths[2], textAlign: ui.TextAlign.right);
    await raster.prepare(_fmt(totalCredit),
        fontSize: 9, bold: true, color: _ledgerIndigo, width: cellWidths[3], textAlign: ui.TextAlign.right);
    await raster.prepare(_fmt(lastBalance),
        fontSize: 9, bold: true, color: _ledgerIndigo, width: cellWidths[4], textAlign: ui.TextAlign.right);

    final reportType = 'Individual Customer';
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) =>
            _header(
              doc.document,
              raster,
              'Customer Ledger',
              company: company,
              reportType: reportType,
            ),
        footer: (context) => _pageFooter(context),
        build: (context) => [
          _customerInfoSection(doc.document, raster, customer,
              contentWidth: contentWidth - 24),
          pw.SizedBox(height: 16),
          _reportMetaBar(now, reportType: reportType),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              _summaryCard(
                'Opening',
                _fmt(0),
                const PdfColor.fromInt(0xFF1E3A8A),
              ),
              pw.SizedBox(width: 8),
              _summaryCard(
                'Total Debit',
                _fmt(totalDebit),
                const PdfColor.fromInt(0xFFEA580C),
              ),
              pw.SizedBox(width: 8),
              _summaryCard(
                'Total Credit',
                _fmt(totalCredit),
                const PdfColor.fromInt(0xFF16A34A),
              ),
              pw.SizedBox(width: 8),
              _summaryCard(
                'Closing Balance',
                _fmt(lastBalance),
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
              0: pw.FlexColumnWidth(1.5),
              1: pw.FlexColumnWidth(3),
              2: pw.FlexColumnWidth(1.3),
              3: pw.FlexColumnWidth(1.3),
              4: pw.FlexColumnWidth(1.3),
            },
            children: [
              _tableHeaderRow([
                'Date',
                'Particulars',
                'Debit (DR)',
                'Credit (CR)',
                'Balance',
              ]),
              ...entries.asMap().entries.map(
                (e) => _entryRow(
                  doc.document,
                  raster,
                  cellWidths,
                  e.value,
                  e.key.isOdd,
                ),
              ),
              _totalRow(
                doc.document,
                raster,
                cellWidths,
                <String>['TOTAL', '', _fmt(totalDebit), _fmt(totalCredit), _fmt(lastBalance)],
              ),
            ],
          ),
        ],
      ),
    );
    return doc.save();
  }

  pw.Widget _header(
    PdfDocument pdfDocument,
    PdfRasterText raster,
    String title, {
    String reportType = 'All Customers',
    required DocCompany company,
  }) {
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 3,
              child: buildRasterCompanyColumn(pdfDocument, raster, company),
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
                  _metaRow('Report Type', reportType),
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

  pw.Widget _reportMetaBar(
    DateTime now, {
    String reportType = 'All Customers',
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
                _metaBadge(
                  'Period',
                  'As of ${DateFormat('MMMM d, yyyy').format(now)}',
                ),
                pw.SizedBox(width: 16),
                _metaBadge('Report Type', reportType),
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

  pw.Widget _customerInfoSection(
    PdfDocument pdfDocument,
    PdfRasterText raster,
    CustomerLedger customer, {
    required double contentWidth,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF8FAFC),
        border: pw.Border.all(color: PdfColors.grey200),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          raster.build(pdfDocument, customer.name,
              fontSize: 14, bold: true, color: _ledgerIndigo, width: contentWidth),
          pw.SizedBox(height: 4),
          pw.Row(
            children: [
              pw.Text(
                'Phone: ',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey600,
                ),
              ),
              pw.SizedBox(width: 2),
              raster.build(pdfDocument, customer.phone,
                  fontSize: 9, bold: false, color: _ledgerGrey700, width: contentWidth),
            ],
          ),
        ],
      ),
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
                    h == 'Debit (DR)' ||
                        h == 'Credit (CR)' ||
                        h == 'Closing Balance' ||
                        h == 'Balance' ||
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

  pw.TableRow _customerRow(
    PdfDocument pdfDocument,
    PdfRasterText raster,
    List<double> cellWidths,
    CustomerLedger c,
    bool odd,
  ) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: odd ? const PdfColor.fromInt(0xFFF8FAFC) : PdfColors.white,
      ),
      children: [
        _cell(pdfDocument, raster, c.name, width: cellWidths[0]),
        _cell(pdfDocument, raster, c.phone, width: cellWidths[1]),
        _cell(pdfDocument, raster, _fmt(c.debit),
            width: cellWidths[2], alignment: pw.Alignment.centerRight),
        _cell(pdfDocument, raster, _fmt(c.credit),
            width: cellWidths[3], alignment: pw.Alignment.centerRight),
        _cell(
          pdfDocument,
          raster,
          _fmt(c.balance),
          width: cellWidths[4],
          alignment: pw.Alignment.centerRight,
          color: _balanceColor(c.status),
          bold: c.status == LedgerStatus.due,
        ),
        _statusBadge(c.status),
      ],
    );
  }

  pw.TableRow _entryRow(
    PdfDocument pdfDocument,
    PdfRasterText raster,
    List<double> cellWidths,
    LedgerEntry entry,
    bool odd,
  ) {
    final dateStr = DateFormat('MMM d, y').format(entry.date);
    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: odd ? const PdfColor.fromInt(0xFFF8FAFC) : PdfColors.white,
      ),
      children: [
        _cell(pdfDocument, raster, dateStr, width: cellWidths[0]),
        _cell(pdfDocument, raster, entry.particulars,
            width: cellWidths[1]),
        _cell(pdfDocument, raster, entry.debit > 0 ? _fmt(entry.debit) : '',
            width: cellWidths[2], alignment: pw.Alignment.centerRight),
        _cell(pdfDocument, raster, entry.credit > 0 ? _fmt(entry.credit) : '',
            width: cellWidths[3], alignment: pw.Alignment.centerRight),
        _cell(
          pdfDocument,
          raster,
          _fmt(entry.balance),
          width: cellWidths[4],
          alignment: pw.Alignment.centerRight,
          bold: entry.balance != 0,
          color: entry.balance != 0 ? _ledgerRed : _ledgerGrey700,
        ),
      ],
    );
  }

  pw.TableRow _totalRow(
    PdfDocument pdfDocument,
    PdfRasterText raster,
    List<double> cellWidths,
    List<String> cells,
  ) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F5F9)),
      children: cells
          .asMap()
          .entries
          .map(
            (e) => _cell(
              pdfDocument,
              raster,
              e.value,
              width: cellWidths[e.key],
              alignment: e.key == 0
                  ? pw.Alignment.centerLeft
                  : pw.Alignment.centerRight,
              color: _ledgerIndigo,
              bold: true,
            ),
          )
          .toList(),
    );
  }

  pw.Widget _statusBadge(LedgerStatus status) {
    final (bg, fg, text) = switch (status) {
      LedgerStatus.settled => (
          const PdfColor.fromInt(0xFFDCFCE7),
          const PdfColor.fromInt(0xFF16A34A),
          'Settled',
        ),
      LedgerStatus.due => (
          const PdfColor.fromInt(0xFFFEE2E2),
          const PdfColor.fromInt(0xFFDC2626),
          'Due',
        ),
      LedgerStatus.advance => (
          const PdfColor.fromInt(0xFFFEF3C7),
          const PdfColor.fromInt(0xFFD97706),
          'Advance',
        ),
    };
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      alignment: pw.Alignment.center,
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: pw.BoxDecoration(
          color: bg,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
        ),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: fg,
          ),
        ),
      ),
    );
  }

  pw.Widget _cell(
    PdfDocument pdfDocument,
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
        pdfDocument,
        text,
        fontSize: 9,
        bold: bold,
        color: color ?? _ledgerGrey700,
        width: width,
        alignment: alignment,
      ),
    );
  }

  Future<void> _prepareCompany(PdfRasterText raster, DocCompany company) async {
    await raster.prepare(company.name,
        fontSize: 20, bold: true, color: _ledgerIndigo, width: 300);
    if (company.address.isNotEmpty) {
      await raster.prepare(company.address,
          fontSize: 9, bold: false, color: _ledgerGrey700, width: 300);
    }
    await raster.prepare('${company.phone} • ${company.email}',
        fontSize: 9, bold: false, color: _ledgerGrey700, width: 300);
  }

  List<double> _cellWidths(double contentWidth, List<double> ratios) {
    final sum = ratios.fold<double>(0, (s, r) => s + r);
    return <double>[
      for (final r in ratios) (contentWidth * r / sum) - 8,
    ];
  }

  ui.Color _balanceColor(LedgerStatus status) => switch (status) {
        LedgerStatus.due => _ledgerRed,
        LedgerStatus.advance => _ledgerAmber,
        LedgerStatus.settled => _ledgerGrey700,
      };

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

  String _safeFilePart(String v) => v
      .trim()
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '')
      .toLowerCase();

  Future<Directory> _downloadDirectory() async {
    if (Platform.isAndroid) {
      final d = Directory('/storage/emulated/0/Download');
      if (await d.exists()) return d;
    }
    return getApplicationDocumentsDirectory();
  }
}
