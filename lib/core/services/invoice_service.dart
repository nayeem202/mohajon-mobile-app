import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../constants/app_constants.dart';
import '../models/sale.dart';
import '../utils/money.dart';
import 'pdf_doc.dart';
import 'pdf_raster_text.dart';

class InvoiceService {
  static const _thermalContentWidth = 72 * PdfPageFormat.mm;
  static const _thermalItemNumberWidth = 17.0;
  static const _thermalQtyWidth = 24.0;
  static const _thermalPriceWidth = 54.0;
  static const _thermalDescriptionWidth =
      _thermalContentWidth -
      _thermalItemNumberWidth -
      _thermalQtyWidth -
      _thermalPriceWidth;

  static const _thermal80 = PdfPageFormat(
    80 * PdfPageFormat.mm,
    double.infinity,
    marginTop: 4 * PdfPageFormat.mm,
    marginBottom: 4 * PdfPageFormat.mm,
    marginLeft: 4 * PdfPageFormat.mm,
    marginRight: 4 * PdfPageFormat.mm,
  );

  Future<Uint8List> buildSaleInvoice(
    Sale sale, {
    String customerName = '',
    String customerPhone = '',
    required DocCompany company,
  }) async {
    final theme = await buildAppPdfTheme();
    final raster = PdfRasterText();
    await _prepareInvoiceRaster(
      raster,
      sale: sale,
      company: company,
      customerName: customerName,
      customerPhone: customerPhone,
      thermal: false,
    );
    final pdf = pw.Document(theme: theme);
    final now = DateTime.now();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => _header(pdf.document, raster, company),
        footer: (context) => _pageFooter(context),
        build: (context) => [
          _invoiceMeta(sale, now),
          pw.SizedBox(height: 16),
          _customerSection(
            pdf.document,
            raster,
            sale,
            customerName: customerName,
            customerPhone: customerPhone,
          ),
          pw.SizedBox(height: 16),
          _itemsTable(pdf.document, raster, sale),
          pw.SizedBox(height: 16),
          _summarySection(sale),
        ],
      ),
    );
    return pdf.save();
  }

  /// Builds an 80mm thermal-roll receipt (the long counter printer format)
  /// used by the "Print invoice" action. Also shareable/saveable to phone.
  Future<Uint8List> buildThermalReceipt(
    Sale sale, {
    String customerName = '',
    String customerPhone = '',
    required DocCompany company,
  }) async {
    final theme = await buildAppPdfTheme();
    final raster = PdfRasterText();
    await _prepareInvoiceRaster(
      raster,
      sale: sale,
      company: company,
      customerName: customerName,
      customerPhone: customerPhone,
      thermal: true,
    );
    final pdf = pw.Document(theme: theme);

    pdf.addPage(
      pw.Page(
        pageFormat: _thermal80,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _receiptMeta(sale),
            _receiptShopHeader(pdf.document, raster, company),
            _receiptDivider(),
            if (customerName.trim().isNotEmpty ||
                sale.customerId.trim().isNotEmpty ||
                customerPhone.trim().isNotEmpty) ...[
              _receiptCustomer(
                pdf.document,
                raster,
                sale,
                customerName: customerName,
                customerPhone: customerPhone,
              ),
            ],
            _receiptDivider(),
            _receiptItems(pdf.document, raster, sale),
            _receiptDivider(),
            _receiptTotals(sale),
            _receiptDivider(),
            _receiptFooter(),
          ],
        ),
      ),
    );
    return pdf.save();
  }

  Future<void> _prepareInvoiceRaster(
    PdfRasterText raster, {
    required Sale sale,
    required DocCompany company,
    required String customerName,
    required String customerPhone,
    required bool thermal,
  }) async {
    const receiptInk = ui.Color(0xFF111111);
    const invoiceIndigo = ui.Color(0xFF1E3A8A);
    const grey800 = ui.Color(0xFF374151);
    const grey600 = ui.Color(0xFF525252);
    const grey500 = ui.Color(0xFF737373);
    final companyWidth = thermal ? _thermalContentWidth : 300.0;
    final itemWidth = thermal ? _thermalDescriptionWidth : 241.0;
    final customerWidth = thermal ? _thermalContentWidth - 48 : 475.0;

    await raster.prepare(
      company.name,
      fontSize: thermal ? 12 : 20,
      bold: true,
      color: thermal ? receiptInk : invoiceIndigo,
      width: companyWidth,
      textAlign: thermal ? ui.TextAlign.center : ui.TextAlign.left,
    );
    final companyFields = <(String, ui.Color)>[
      (company.tagline, grey600),
      (company.address, thermal ? grey600 : grey500),
      (company.phone, thermal ? grey600 : grey500),
      (company.email, grey500),
    ];
    for (final field in companyFields) {
      if (field.$1.isNotEmpty) {
        await raster.prepare(
          field.$1,
          fontSize: thermal ? 8 : 9,
          bold: false,
          color: thermal && field.$1 == company.address
              ? const ui.Color(0xFF525252)
              : field.$2,
          width: companyWidth,
          textAlign: thermal ? ui.TextAlign.center : ui.TextAlign.left,
        );
      }
    }

    final displayName = customerName.trim().isNotEmpty
        ? customerName.trim()
        : sale.customerId.trim().isNotEmpty
        ? sale.customerId.trim()
        : 'Walk-in customer';
    await raster.prepare(
      displayName,
      fontSize: thermal ? 9 : 12,
      bold: true,
      color: grey800,
      width: customerWidth,
      textAlign: thermal ? ui.TextAlign.right : ui.TextAlign.left,
    );
    if (customerPhone.isNotEmpty) {
      await raster.prepare(
        customerPhone,
        fontSize: thermal ? 9 : 9,
        bold: false,
        color: grey600,
        width: customerWidth,
        textAlign: thermal ? ui.TextAlign.right : ui.TextAlign.left,
      );
    }
    for (final item in sale.items) {
      await raster.prepare(
        item.name,
        fontSize: thermal ? 8.5 : 9,
        bold: false,
        color: thermal ? const ui.Color(0xFF111111) : grey800,
        width: itemWidth,
      );
    }
  }

  pw.Widget _receiptShopHeader(
    PdfDocument pdf,
    PdfRasterText raster,
    DocCompany company,
  ) {
    final shopName = company.name.trim() == AppConstants.appName
        ? ''
        : company.name.trim();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.SizedBox(height: 5),
        if (shopName.isNotEmpty)
          _rasterText(
            pdf,
            raster,
            shopName,
            fontSize: 12,
            bold: true,
            color: const ui.Color(0xFF111111),
            width: _thermalContentWidth,
            alignment: pw.Alignment.center,
          ),
        if (company.address.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            'Address',
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
          _rasterText(
            pdf,
            raster,
            company.address,
            fontSize: 8,
            color: const ui.Color(0xFF525252),
            width: _thermalContentWidth,
            alignment: pw.Alignment.center,
          ),
        ],
        if (company.phone.isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text(
            'Phone: ${company.phone}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
        if (company.tin.isNotEmpty || company.bin.isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text(
            [
              if (company.tin.isNotEmpty) 'TIN: ${company.tin}',
              if (company.bin.isNotEmpty) 'BIN: ${company.bin}',
            ].join('   '),
            style: const pw.TextStyle(fontSize: 7),
          ),
        ],
      ],
    );
  }

  pw.Widget _receiptDivider() => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Container(
      height: 1,
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
            color: PdfColors.grey700,
            width: 0.55,
            style: pw.BorderStyle.dashed,
          ),
        ),
      ),
    ),
  );

  pw.Widget _receiptMeta(Sale sale) {
    final receiptNumber = sale.invoiceNumber.isNotEmpty
        ? sale.invoiceNumber
        : sale.saleId;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          'Order Receipt',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 1),
        pw.Text('#$receiptNumber', style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 4),
        _receiptLine('Date', DateFormat('dd/MM/yyyy').format(sale.createdAt)),
        _receiptLine('Time', DateFormat('HH:mm:ss').format(sale.createdAt)),
      ],
    );
  }

  pw.Widget _receiptCustomer(
    PdfDocument pdf,
    PdfRasterText raster,
    Sale sale, {
    String customerName = '',
    String customerPhone = '',
  }) {
    final name = customerName.trim().isNotEmpty
        ? customerName.trim()
        : sale.customerId.trim().isNotEmpty
        ? sale.customerId.trim()
        : 'Walk-in customer';
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _receiptRasterLine(pdf, raster, 'Client', name, boldValue: true),
        if (customerPhone.trim().isNotEmpty)
          _receiptRasterLine(
            pdf,
            raster,
            'Phone',
            customerPhone.trim(),
            color: const ui.Color(0xFF525252),
          ),
        _receiptLine('Payment', sale.paymentMethod.displayName),
      ],
    );
  }

  pw.Widget _receiptItems(PdfDocument pdf, PdfRasterText raster, Sale sale) {
    final descriptionWidth = _thermalDescriptionWidth;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          children: [
            _receiptFixedCell(
              'ITEM',
              width: _thermalItemNumberWidth,
              bold: true,
            ),
            _receiptFixedCell(
              'QTY',
              width: _thermalQtyWidth,
              align: pw.TextAlign.center,
              bold: true,
            ),
            pw.SizedBox(
              width: descriptionWidth,
              child: pw.Text(
                'DESCRIPTION',
                style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            _receiptFixedCell(
              'PRICE',
              width: _thermalPriceWidth,
              align: pw.TextAlign.right,
              bold: true,
            ),
          ],
        ),
        pw.SizedBox(height: 2),
        for (final entry in sale.items.asMap().entries)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _receiptFixedCell(
                  '${entry.key + 1}',
                  width: _thermalItemNumberWidth,
                ),
                _receiptFixedCell(
                  _qtyText(entry.value.qty),
                  width: _thermalQtyWidth,
                  align: pw.TextAlign.center,
                ),
                pw.SizedBox(
                  width: descriptionWidth,
                  child: _rasterText(
                    pdf,
                    raster,
                    entry.value.name,
                    fontSize: 8.5,
                    color: const ui.Color(0xFF111111),
                    width: descriptionWidth,
                  ),
                ),
                _receiptFixedCell(
                  money(entry.value.lineTotal),
                  width: _thermalPriceWidth,
                  align: pw.TextAlign.right,
                ),
              ],
            ),
          ),
      ],
    );
  }

  pw.Widget _receiptFixedCell(
    String text, {
    required double width,
    pw.TextAlign align = pw.TextAlign.left,
    bool bold = false,
  }) {
    return pw.SizedBox(
      width: width,
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 7,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: PdfColors.black,
        ),
      ),
    );
  }

  pw.Widget _receiptTotals(Sale sale) {
    final itemsTotal = sale.items.fold<double>(0, (s, i) => s + i.lineTotal);
    final vatAmount = itemsTotal * (sale.vatPercent / 100);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _receiptTotalRow('Subtotal', money(itemsTotal)),
        if (sale.vatPercent > 0)
          _receiptTotalRow(
            'VAT (${sale.vatPercent.toStringAsFixed(1)}%)',
            money(vatAmount),
          ),
        if (sale.charge > 0) _receiptTotalRow('Charge', money(sale.charge)),
        if (sale.discount > 0)
          _receiptTotalRow('Discount', '-${money(sale.discount)}'),
        pw.SizedBox(height: 4),
        _receiptTotalRow('Order Total', money(sale.totalAmount), bold: true),
        pw.SizedBox(height: 4),
        _receiptTotalRow('Paid', money(sale.paidAmount)),
        if (sale.dueAmount > 0)
          _receiptTotalRow(
            'Due',
            money(sale.dueAmount),
            color: const PdfColor.fromInt(0xFFDC2626),
          ),
      ],
    );
  }

  pw.Widget _receiptTotalRow(
    String label,
    String value, {
    PdfColor? color,
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: bold ? 10 : 8,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: PdfColors.black,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: bold ? 10 : 8,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color ?? PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _receiptLine(
    String label,
    String value, {
    bool boldValue = false,
    PdfColor? valueColor,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 48,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey600,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: boldValue
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
                color: valueColor ?? PdfColors.grey800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _receiptRasterLine(
    PdfDocument pdf,
    PdfRasterText raster,
    String label,
    String value, {
    bool boldValue = false,
    ui.Color color = const ui.Color(0xFF374151),
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 48,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey600,
              ),
            ),
          ),
          pw.Expanded(
            child: _rasterText(
              pdf,
              raster,
              value,
              fontSize: 9,
              bold: boldValue,
              color: color,
              width: _thermalContentWidth - 48,
              alignment: pw.Alignment.centerRight,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _receiptFooter() {
    return pw.Column(
      children: [
        pw.SizedBox(height: 3),
        pw.Text(
          '**************** THANK YOU! ****************',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 7),
        ),
        pw.SizedBox(height: 9),
        pw.Text(
          'JOIN OUR E-MAIL\nLIST FOR SPECIAL\nOFFERS AND DISCOUNTS',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          'E-MAIL  __________________________',
          style: const pw.TextStyle(fontSize: 7),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          'GUEST NAME  _____________________',
          style: const pw.TextStyle(fontSize: 7),
        ),
        pw.SizedBox(height: 7),
        pw.Text(
          'Powered by ${AppConstants.appName}',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
        ),
      ],
    );
  }

  String _qtyText(double qty) =>
      qty % 1 == 0 ? qty.toStringAsFixed(0) : qty.toString();

  pw.Widget _header(PdfDocument pdf, PdfRasterText raster, DocCompany company) {
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
                _metaBadge(
                  'Invoice #',
                  sale.invoiceNumber.isNotEmpty
                      ? sale.invoiceNumber
                      : sale.saleId,
                ),
                pw.SizedBox(width: 16),
                _metaBadge(
                  'Date',
                  DateFormat('MMM dd, yyyy').format(sale.createdAt),
                ),
                pw.SizedBox(width: 16),
                _metaBadge(
                  'Generated',
                  DateFormat('MMM dd, yyyy HH:mm').format(now),
                ),
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

  pw.Widget _customerSection(
    PdfDocument pdf,
    PdfRasterText raster,
    Sale sale, {
    String customerName = '',
    String customerPhone = '',
  }) {
    final displayName = customerName.isNotEmpty
        ? customerName
        : sale.customerId;
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
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: pw.BoxDecoration(
                  color: sale.paymentStatus == PaymentStatus.paid
                      ? const PdfColor.fromInt(0xFFDCFCE7)
                      : sale.paymentStatus == PaymentStatus.partial
                      ? const PdfColor.fromInt(0xFFFEF9C3)
                      : const PdfColor.fromInt(0xFFFEE2E2),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(10),
                  ),
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
          _rasterText(
            pdf,
            raster,
            displayName,
            fontSize: 12,
            bold: true,
            color: const ui.Color(0xFF374151),
            width: 475,
          ),
          pw.SizedBox(height: 4),
          if (customerPhone.isNotEmpty)
            _rasterText(
              pdf,
              raster,
              customerPhone,
              fontSize: 9,
              color: const ui.Color(0xFF525252),
              width: 475,
            ),
          pw.Text(
            'ID: ${sale.customerId}',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
        ],
      ),
    );
  }

  pw.Widget _itemsTable(PdfDocument pdf, PdfRasterText raster, Sale sale) {
    final itemsTotal = sale.items.fold<double>(0, (s, i) => s + i.lineTotal);
    return pw.Table(
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
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
          (e) => _itemRow(pdf, raster, e.value, e.key + 1, e.key.isOdd),
        ),
        _subtotalRow(itemsTotal),
      ],
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
                    h == '#' || h == 'Qty' || h == 'Unit Price' || h == 'Total'
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

  pw.TableRow _itemRow(
    PdfDocument pdf,
    PdfRasterText raster,
    SaleItem item,
    int index,
    bool odd,
  ) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: odd ? const PdfColor.fromInt(0xFFF8FAFC) : PdfColors.white,
      ),
      children: [
        _cell('$index', align: pw.TextAlign.center),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          child: _rasterText(
            pdf,
            raster,
            item.name,
            fontSize: 9,
            color: const ui.Color(0xFF374151),
            width: 241,
          ),
        ),
        _cell('${item.qty.toInt()}', align: pw.TextAlign.center),
        _cell(money(item.unitPrice), align: pw.TextAlign.right),
        _cell(money(item.lineTotal), align: pw.TextAlign.right),
      ],
    );
  }

  pw.TableRow _subtotalRow(double itemsTotal) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F5F9)),
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
    final taxable = (itemsTotal - sale.discount)
        .clamp(0, double.infinity)
        .toDouble();
    final vatAmount = taxable * (sale.vatPercent / 100);

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
                _summaryLine('Subtotal', itemsTotal, PdfColors.grey700),
                pw.SizedBox(height: 4),
                pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                pw.SizedBox(height: 4),
                _summaryLine(
                  'VAT (${sale.vatPercent.toStringAsFixed(1)}%)',
                  vatAmount,
                  const PdfColor.fromInt(0xFF1E3A8A),
                ),
                if (sale.charge > 0)
                  _summaryLine(
                    'Charge',
                    sale.charge,
                    const PdfColor.fromInt(0xFFEA580C),
                  ),
                if (sale.discount > 0)
                  _summaryLine(
                    'Discount',
                    sale.discount,
                    const PdfColor.fromInt(0xFFEA580C),
                  ),
                pw.SizedBox(height: 4),
                pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                pw.SizedBox(height: 4),
                _summaryLine(
                  'Total Amount',
                  sale.totalAmount,
                  const PdfColor.fromInt(0xFF1E3A8A),
                ),
                _summaryLine(
                  'Paid Amount',
                  sale.paidAmount,
                  const PdfColor.fromInt(0xFF16A34A),
                ),
                if (sale.dueAmount > 0)
                  _summaryLine(
                    'Due Amount',
                    sale.dueAmount,
                    const PdfColor.fromInt(0xFFDC2626),
                  ),
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

  pw.Widget _rasterText(
    PdfDocument pdf,
    PdfRasterText raster,
    String text, {
    required double fontSize,
    required ui.Color color,
    required double width,
    bool bold = false,
    pw.Alignment alignment = pw.Alignment.centerLeft,
  }) {
    return raster.build(
      pdf,
      text,
      fontSize: fontSize,
      bold: bold,
      color: color,
      width: width,
      alignment: alignment,
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
