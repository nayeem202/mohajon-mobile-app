import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../core/services/download_export_service.dart';
import '../models/receipt.dart';
import '../services/receipt_pdf_service.dart';

class ReceiptPreviewScreen extends StatelessWidget {
  const ReceiptPreviewScreen({super.key, required this.receipt});

  final Receipt receipt;

  Future<void> _downloadPdf(BuildContext context) async {
    try {
      final service = ReceiptPdfService();
      final bytes = await service.buildReceiptPdf(receipt);

      final savedPath = await DownloadExportService().saveFileToDownloads(
        fileName: 'receipt-${receipt.safeReceiptNumber}.pdf',
        mimeType: 'application/pdf',
        bytes: bytes,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to Downloads')),
        );
        if (savedPath != null) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ReceiptPdfService();
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt preview')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton.icon(
          onPressed: () => _downloadPdf(context),
          icon: const Icon(Icons.download_rounded),
          label: const Text('Download'),
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
