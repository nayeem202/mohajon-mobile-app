import 'dart:typed_data';

import 'package:barcode/barcode.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

final _labelCurrency = NumberFormat.currency(locale: 'en_US', symbol: 'Tk. ');

String _labelMoney(num value) => _labelCurrency.format(value);

class BarcodeLabel {
  const BarcodeLabel({
    required this.code,
    required this.name,
    required this.price,
  });

  final String code;
  final String name;
  final double price;
}

class BarcodeLabelService {
  final _barcode = Barcode.code128();

  /// Builds a printable sheet of barcode/price stickers.
  ///
  /// A4 layout with [columns] x [rows] stickies; each [label] is repeated
  /// [copies] times so the first labels can be filled across the sheet.
  Future<Uint8List> buildLabels(
    List<BarcodeLabel> labels, {
    PdfPageFormat format = PdfPageFormat.a4,
    int copies = 1,
    int columns = 2,
    int rows = 5,
  }) {
    final queue = <BarcodeLabel>[];
    for (final label in labels) {
      for (var i = 0; i < copies; i++) {
        queue.add(label);
      }
    }

    final document = pw.Document();
    document.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(10),
        build: (context) {
          return pw.Column(
            children: [
              for (var row = 0; row < rows; row++) ...[
                if (row != 0) pw.SizedBox(height: 6),
                pw.Expanded(
                  child: pw.Row(
                    children: [
                      for (var col = 0; col < columns; col++) ...[
                        if (col != 0) pw.SizedBox(width: 6),
                        pw.Expanded(
                          child: _label(queue, row * columns + col),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );

    return document.save();
  }

  pw.Widget _label(List<BarcodeLabel> queue, int index) {
    if (index >= queue.length) return pw.SizedBox.shrink();
    final label = queue[index];

    final svg = _barcode.toSvg(
      label.code,
      width: 600,
      height: 160,
      drawText: false,
    );

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      padding: const pw.EdgeInsets.all(6),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            label.name,
            maxLines: 1,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 2,
            ),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF7EDD8),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              _labelMoney(label.price),
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 5),
          pw.SvgImage(svg: svg, height: 38),
          pw.SizedBox(height: 3),
          pw.Text(
            label.code,
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
    );
  }
}