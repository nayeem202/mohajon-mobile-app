import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/download_export_service.dart';
import '../models/customer_ledger.dart';
import '../models/ledger_entry.dart';

class LedgerPdfService {
  final _downloadExportService = DownloadExportService();
  pw.Font? _baseFont;
  pw.Font? _boldFont;

  Future<pw.ThemeData> _buildTheme() async {
    if (_baseFont == null) {
      final regular = await rootBundle.load('assets/fonts/NotoSansBengali-Regular.ttf');
      _baseFont = pw.Font.ttf(regular);
    }
    if (_boldFont == null) {
      final bold = await rootBundle.load('assets/fonts/NotoSansBengali-Bold.ttf');
      _boldFont = pw.Font.ttf(bold);
    }
    return pw.ThemeData.withFont(base: _baseFont!, bold: _boldFont!);
  }

  Future<File> saveAllCustomers(List<CustomerLedger> customers) async {
    final bytes = await buildAllCustomersPdf(customers);
    return _saveFile('customer-ledger-all.pdf', bytes);
  }

  Future<File> saveCustomerDetail(
    CustomerLedger customer,
    List<LedgerEntry> entries,
  ) async {
    final bytes = await buildCustomerDetailPdf(customer, entries);
    final fileName =
        'ledger-${_safeFilePart(customer.name.isEmpty ? 'customer' : customer.name)}.pdf';
    return _saveFile(fileName, bytes);
  }

  Future<Uint8List> buildAllCustomersPdf(List<CustomerLedger> customers) async {
    final theme = await _buildTheme();
    final doc = pw.Document(theme: theme);
    final totalOutstanding =
        customers.fold<double>(0, (s, c) => s + c.balance);
    final withDues = customers.where((c) => c.hasDue).length;
    final now = DateTime.now();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => _header('Customer Ledger'),
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
              horizontalInside:
                  pw.BorderSide(color: PdfColors.grey300, width: 0.5),
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
                    (e) => _customerRow(e.value, e.key.isOdd),
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
  ) async {
    final theme = await _buildTheme();
    final doc = pw.Document(theme: theme);
    final totalDebit = entries.fold<double>(0, (s, e) => s + e.debit);
    final totalCredit = entries.fold<double>(0, (s, e) => s + e.credit);
    final lastBalance = entries.isEmpty ? 0.0 : entries.last.balance;
    final now = DateTime.now();

    final reportType = 'Individual Customer';
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => _header('Customer Ledger', reportType: reportType),
        footer: (context) => _pageFooter(context),
        build: (context) => [
          _customerInfoSection(customer),
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
              horizontalInside:
                  pw.BorderSide(color: PdfColors.grey300, width: 0.5),
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
                    (e) => _entryRow(e.value, e.key.isOdd),
                  ),
              _totalRow(
                ['TOTAL', '', _fmt(totalDebit), _fmt(totalCredit), _fmt(lastBalance)],
              ),
            ],
          ),
        ],
      ),
    );
    return doc.save();
  }

  pw.Widget _header(String title, {String reportType = 'All Customers'}) {
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
                    style: pw.TextStyle(
fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Dhaka, Bangladesh',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey500,
                    ),
                  ),
                  pw.Text(
                    '+880 1700-000000',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey500,
                    ),
                  ),
                  pw.Text(
                    'hello@haalkhata.com',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey500,
                    ),
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
                      style: const pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  _metaRow('Generated', DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())),
                  _metaRow('Period', 'As of ${DateFormat('MMMM d, yyyy').format(DateTime.now())}'),
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
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _reportMetaBar(DateTime now, {String reportType = 'All Customers'}) {
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
                _metaBadge('Period', 'As of ${DateFormat('MMMM d, yyyy').format(now)}'),
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
          style: const pw.TextStyle(
            fontSize: 9,
            color: PdfColors.grey700,
          ),
        ),
      ],
    );
  }

  pw.Widget _customerInfoSection(CustomerLedger customer) {
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
          pw.Text(
            customer.name,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF1E3A8A),
            ),
          ),
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
              pw.Text(
                customer.phone,
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey800,
                ),
              ),
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
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey500,
              ),
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
      decoration: const pw.BoxDecoration(
        color: PdfColor.fromInt(0xFF1E3A8A),
      ),
      children: headers
          .map(
            (h) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: pw.Text(
                h,
                textAlign: h == 'Debit (DR)' ||
                        h == 'Credit (CR)' ||
                        h == 'Closing Balance' ||
                        h == 'Balance' ||
                        h == 'Status'
                    ? pw.TextAlign.center
                    : pw.TextAlign.left,
                style: const pw.TextStyle(
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

  pw.TableRow _customerRow(CustomerLedger c, bool odd) {
    final settled = !c.hasDue;
    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: odd
            ? const PdfColor.fromInt(0xFFF8FAFC)
            : PdfColors.white,
      ),
      children: [
        _cell(c.name),
        _cell(c.phone),
        _cell(_fmt(c.debit), align: pw.TextAlign.right),
        _cell(_fmt(c.credit), align: pw.TextAlign.right),
        _cell(
          _fmt(c.balance),
          align: pw.TextAlign.right,
          color: c.hasDue
              ? const PdfColor.fromInt(0xFFDC2626)
              : PdfColors.grey700,
          bold: c.hasDue,
        ),
        _statusBadge(settled),
      ],
    );
  }

  pw.TableRow _entryRow(LedgerEntry entry, bool odd) {
    final dateStr = DateFormat('MMM d, y').format(entry.date);
    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: odd
            ? const PdfColor.fromInt(0xFFF8FAFC)
            : PdfColors.white,
      ),
      children: [
        _cell(dateStr),
        _cell(entry.particulars),
        _cell(
          entry.debit > 0 ? _fmt(entry.debit) : '',
          align: pw.TextAlign.right,
        ),
        _cell(
          entry.credit > 0 ? _fmt(entry.credit) : '',
          align: pw.TextAlign.right,
        ),
        _cell(
          _fmt(entry.balance),
          align: pw.TextAlign.right,
          bold: entry.balance != 0,
          color: entry.balance != 0
              ? const PdfColor.fromInt(0xFFDC2626)
              : PdfColors.grey700,
        ),
      ],
    );
  }

  pw.TableRow _totalRow(List<String> cells) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF1F5F9),
      ),
      children: cells
          .map(
            (c) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
              child: pw.Text(
                c,
                textAlign: c == 'TOTAL' ? pw.TextAlign.left : pw.TextAlign.right,
                style: const pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(0xFF1E3A8A),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  pw.Widget _statusBadge(bool settled) {
    final bg = settled
        ? const PdfColor.fromInt(0xFFDCFCE7)
        : const PdfColor.fromInt(0xFFFEE2E2);
    final fg = settled
        ? const PdfColor.fromInt(0xFF16A34A)
        : const PdfColor.fromInt(0xFFDC2626);
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
          settled ? 'Settled' : 'Due',
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
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
            ),
          ],
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'Generated on ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey400),
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
