import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/services/download_export_service.dart';
import '../models/receipt.dart';

class ReceiptPdfService {
  final _downloadExportService = DownloadExportService();

  Future<Uint8List> buildReceiptPdf(Receipt receipt) async {
    final document = pw.Document();
    final dateText = DateFormat('MMM dd, yyyy').format(receipt.date);

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _header(receipt),
              pw.SizedBox(height: 16),
              pw.Divider(thickness: 1),
              pw.Center(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 10),
                  child: pw.Text(
                    'SALES RECEIPT',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 18),
              _details(receipt, dateText),
              pw.SizedBox(height: 22),
              _itemsTable(receipt),
              pw.SizedBox(height: 16),
              _summary(receipt),
              pw.Spacer(),
              _footer(),
            ],
          );
        },
      ),
    );

    return document.save();
  }

  Future<File> saveToDownloads(Receipt receipt) async {
    final bytes = await buildReceiptPdf(receipt);
    final fileName = 'receipt-${receipt.safeReceiptNumber}.pdf';
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
      return _writeReceiptFile(directory, fileName, bytes);
    } on FileSystemException {
      final fallback = await getApplicationDocumentsDirectory();
      return _writeReceiptFile(fallback, fileName, bytes);
    }
  }

  Future<File> _writeReceiptFile(
    Directory directory,
    String fileName,
    Uint8List bytes,
  ) async {
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<Directory> _downloadDirectory() async {
    if (Platform.isAndroid) {
      final downloads = Directory('/storage/emulated/0/Download');
      if (await downloads.exists()) return downloads;
    }
    return getApplicationDocumentsDirectory();
  }

  pw.Widget _header(Receipt receipt) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          receipt.companyName,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 5),
        pw.Text(receipt.companyAddress, textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 3),
        pw.Text(receipt.companyPhone, textAlign: pw.TextAlign.center),
      ],
    );
  }

  pw.Widget _details(Receipt receipt, String dateText) {
    return pw.Column(
      children: [
        _detailRow('Receipt Number', receipt.receiptNumber, 'Date', dateText),
        pw.SizedBox(height: 8),
        _detailRow(
          'Customer Name',
          receipt.customerName,
          'Payment Method',
          receipt.displayPaymentMethod,
        ),
        if (receipt.customerPhone.trim().isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Text(
                'Customer Phone: ',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Expanded(child: pw.Text(receipt.customerPhone)),
            ],
          ),
        ],
      ],
    );
  }

  pw.Widget _detailRow(
    String leftLabel,
    String leftValue,
    String rightLabel,
    String rightValue,
  ) {
    return pw.Row(
      children: [
        pw.Expanded(child: _detailCell(leftLabel, leftValue)),
        pw.SizedBox(width: 24),
        pw.Expanded(child: _detailCell(rightLabel, rightValue)),
      ],
    );
  }

  pw.Widget _detailCell(String label, String value) {
    return pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$label: ',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.TextSpan(text: value),
        ],
      ),
    );
  }

  pw.Widget _itemsTable(Receipt receipt) {
    return pw.Table(
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.6),
        bottom: pw.BorderSide(color: PdfColors.grey600),
        top: pw.BorderSide(color: PdfColors.grey600),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(4),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(1.5),
        3: pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _tableHeader('Description'),
            _tableHeader('Qty', align: pw.TextAlign.center),
            _tableHeader('Price', align: pw.TextAlign.right),
            _tableHeader('Total', align: pw.TextAlign.right),
          ],
        ),
        for (final item in receipt.items)
          pw.TableRow(
            children: [
              _tableCell(item.description),
              _tableCell('${item.quantity}', align: pw.TextAlign.center),
              _tableCell(receiptMoney(item.price), align: pw.TextAlign.right),
              _tableCell(receiptMoney(item.total), align: pw.TextAlign.right),
            ],
          ),
      ],
    );
  }

  pw.Widget _tableHeader(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  pw.Widget _tableCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      child: pw.Text(text, textAlign: align),
    );
  }

  pw.Widget _summary(Receipt receipt) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.SizedBox(
        width: 230,
        child: pw.Column(
          children: [
            _summaryRow('Subtotal', receiptMoney(receipt.subtotal)),
            if (receipt.discountAmount > 0)
              _summaryRow(
                'Discount (${receipt.discountPercent.toStringAsFixed(2)}%)',
                '-${receiptMoney(receipt.discountAmount)}',
                valueColor: PdfColors.green,
              ),
            _summaryRow(
              'Tax (${receipt.taxPercent.toStringAsFixed(2)}%)',
              receiptMoney(receipt.taxAmount),
            ),
            pw.Divider(thickness: 1),
            _summaryRow(
              'Total',
              receiptMoney(receipt.total),
              labelSize: 15,
              valueSize: 15,
              bold: true,
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _summaryRow(
    String label,
    String value, {
    PdfColor? valueColor,
    double labelSize = 11,
    double valueSize = 11,
    bool bold = false,
  }) {
    final weight = bold ? pw.FontWeight.bold : pw.FontWeight.normal;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: labelSize, fontWeight: weight),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: valueSize,
              fontWeight: weight,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _footer() {
    return pw.Column(
      children: [
        pw.Divider(),
        pw.SizedBox(height: 10),
        pw.Text(
          'Thank you for your business!',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'This is a computer-generated receipt.',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ],
    );
  }
}
