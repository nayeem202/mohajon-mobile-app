import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../models/receipt.dart';
import '../services/receipt_pdf_service.dart';

class ReceiptPreviewScreen extends StatelessWidget {
  const ReceiptPreviewScreen({super.key, required this.receipt});

  final Receipt receipt;

  @override
  Widget build(BuildContext context) {
    final service = ReceiptPdfService();
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt preview')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Confirm Checkout'),
        ),
      ),
      body: PdfPreview(
        canChangeOrientation: false,
        canChangePageFormat: false,
        pdfFileName: 'receipt-${receipt.safeReceiptNumber}.pdf',
        build: (_) => service.buildReceiptPdf(receipt),
      ),
    );
  }
}
