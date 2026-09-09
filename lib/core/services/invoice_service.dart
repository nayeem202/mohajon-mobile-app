import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../constants/app_constants.dart';
import '../models/sale.dart';
import '../utils/money.dart';
import 'pdf_doc.dart';

class InvoiceService {
  Future<Uint8List> buildSaleInvoice(
    Sale sale, {
    String customerName = '',
    String customerPhone = '',
    required DocCompany company,
  }) async {
    final theme = await buildAppPdfTheme();
    final pdf = pw.Document(theme: theme);
    final now = DateTime.now();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => _header(company),
        footer: (context) => _pageFooter(context),
        build: (context) => [
          _invoiceMeta(sale, now),
          pw.SizedBox(height: 16),
          _customerSection(sale, customerName: customerName, customerPhone: customerPhone),
          pw.SizedBox(height: 16),
          _itemsTable(sale),
          pw.SizedBox(height: 16),
          _summarySection(sale),
        ],
      ),
    );
    return pdf.save();
  }

  pw.Widget _header(DocCompany company) {
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 3,
              child: buildCompanyColumn(company),
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
                      'INVOICE',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
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
            color: PdfColor.fromInt(0xFF1E3A8A),
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
          ),
        ),
      ],
    );
  }

  pw.Widget _invoiceMeta(Sale sale, DateTime now) {
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
                _metaBadge('Invoice #', sale.saleId),
                pw.SizedBox(width: 16),
                _metaBadge(
                  'Date',
                  DateFormat('MMM dd, yyyy').format(sale.createdAt),
                ),
                pw.SizedBox(width: 16),
                _metaBadge('Generated', DateFormat('MMM dd, yyyy HH:mm').format(now)),
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
          style: pw.TextStyle(
            fontSize: 9,
            color: PdfColors.grey700,
          ),
        ),
      ],
    );
  }

  pw.Widget _customerSection(Sale sale, {String customerName = '', String customerPhone = ''}) {
    final displayName = customerName.isNotEmpty ? customerName : sale.customerId;
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
          pw.Row(
            children: [
              pw.Text(
                'Customer',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: const PdfColor.fromInt(0xFF1E3A8A),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: sale.paymentStatus == PaymentStatus.paid
                      ? const PdfColor.fromInt(0xFFDCFCE7)
                      : sale.paymentStatus == PaymentStatus.partial
                          ? const PdfColor.fromInt(0xFFFEF9C3)
                          : const PdfColor.fromInt(0xFFFEE2E2),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                ),
                child: pw.Text(
                  sale.paymentStatus == PaymentStatus.paid
                      ? 'Paid'
                      : sale.paymentStatus == PaymentStatus.partial
                          ? 'Partial'
                          : 'Due',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: sale.paymentStatus == PaymentStatus.paid
                        ? const PdfColor.fromInt(0xFF16A34A)
                        : sale.paymentStatus == PaymentStatus.partial
                            ? const PdfColor.fromInt(0xFFD97706)
                            : const PdfColor.fromInt(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            displayName,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 4),
          if (customerPhone.isNotEmpty)
            pw.Text(
              customerPhone,
              style: pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey600,
              ),
            ),
          pw.Text(
            'ID: ${sale.customerId}',
            style: pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey500,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _itemsTable(Sale sale) {
    final itemsTotal = sale.items.fold<double>(0, (s, i) => s + i.lineTotal);
    return pw.Table(
      border: pw.TableBorder(
        horizontalInside:
            pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        bottom: pw.BorderSide(color: PdfColors.grey600, width: 0.5),
        top: pw.BorderSide(color: PdfColors.grey600, width: 0.5),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(0.5),
        1: pw.FlexColumnWidth(3),
        2: pw.FlexColumnWidth(0.7),
        3: pw.FlexColumnWidth(1),
        4: pw.FlexColumnWidth(1),
      },
      children: [
        _tableHeaderRow(['#', 'Item', 'Qty', 'Unit Price', 'Total']),
        ...sale.items.asMap().entries.map(
              (e) => _itemRow(e.value, e.key + 1, e.key.isOdd),
            ),
        _subtotalRow(itemsTotal),
      ],
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
                textAlign: h == '#' || h == 'Qty' || h == 'Unit Price' || h == 'Total'
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

  pw.TableRow _itemRow(SaleItem item, int index, bool odd) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: odd
            ? const PdfColor.fromInt(0xFFF8FAFC)
            : PdfColors.white,
      ),
      children: [
        _cell('$index', align: pw.TextAlign.center),
        _cell(item.name),
        _cell('${item.qty.toInt()}', align: pw.TextAlign.center),
        _cell(money(item.unitPrice), align: pw.TextAlign.right),
        _cell(money(item.lineTotal), align: pw.TextAlign.right),
      ],
    );
  }

  pw.TableRow _subtotalRow(double itemsTotal) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF1F5F9),
      ),
      children: [
        _cell('', align: pw.TextAlign.center),
        _cell(''),
        _cell('', align: pw.TextAlign.center),
        _cell('Subtotal', align: pw.TextAlign.right, bold: true),
        _cell(money(itemsTotal), align: pw.TextAlign.right, bold: true),
      ],
    );
  }

  pw.Widget _summarySection(Sale sale) {
    final itemsTotal = sale.items.fold<double>(0, (s, i) => s + i.lineTotal);
    final vatAmount = itemsTotal * (sale.vatPercent / 100);

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF8FAFC),
        border: pw.Border.all(color: PdfColors.grey200),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _summaryLine('Subtotal', itemsTotal,
                    PdfColors.grey700),
                pw.SizedBox(height: 4),
                pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                pw.SizedBox(height: 4),
                _summaryLine(
                  'VAT (${sale.vatPercent.toStringAsFixed(1)}%)',
                  vatAmount,
                  const PdfColor.fromInt(0xFF1E3A8A),
                ),
                if (sale.charge > 0)
                  _summaryLine('Charge', sale.charge,
                      const PdfColor.fromInt(0xFFEA580C)),
                if (sale.discount > 0)
                  _summaryLine('Discount', sale.discount,
                      const PdfColor.fromInt(0xFFEA580C)),
                pw.SizedBox(height: 4),
                pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                pw.SizedBox(height: 4),
                _summaryLine('Total Amount', sale.totalAmount,
                    const PdfColor.fromInt(0xFF1E3A8A)),
                _summaryLine('Paid Amount', sale.paidAmount,
                    const PdfColor.fromInt(0xFF16A34A)),
                if (sale.dueAmount > 0)
                  _summaryLine('Due Amount', sale.dueAmount,
                      const PdfColor.fromInt(0xFFDC2626)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _summaryLine(String label, double amount, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
          pw.Text(
            money(amount),
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
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
              '${AppConstants.appName}  Confidential',
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
}