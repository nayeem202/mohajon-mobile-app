import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../constants/app_constants.dart';
import '../models/sale.dart';
import '../utils/money.dart';

class InvoiceService {
  Future<Uint8List> buildSaleInvoice(Sale sale) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              AppConstants.appName,
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text('Invoice: ${sale.saleId}'),
            pw.SizedBox(height: 8),
            ...sale.items.map(
              (item) => pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(child: pw.Text('${item.name} x ${item.qty}')),
                  pw.Text(money(item.lineTotal)),
                ],
              ),
            ),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [pw.Text('Total'), pw.Text(money(sale.totalAmount))],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [pw.Text('Paid'), pw.Text(money(sale.paidAmount))],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [pw.Text('Due'), pw.Text(money(sale.dueAmount))],
            ),
          ],
        ),
      ),
    );
    return pdf.save();
  }
}
