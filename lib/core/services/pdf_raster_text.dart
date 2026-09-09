import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'pdf_doc.dart';

class _Raster {
  _Raster(this.bytes, this.pxW, this.pxH, this.ptW, this.ptH);

  final Uint8List bytes;
  final int pxW;
  final int pxH;
  final double ptW;
  final double ptH;
}

/// Renders text with Flutter's own HarfBuzz text shaper (correct Bengali
/// conjuncts, vowel signs and reordering) and embeds the resulting glyph
/// raster as an image into a `package:pdf` document.
///
/// The `pdf` package only maps Unicode characters straight to glyphs and
/// offers no complex-script shaping (Arabic excluded), so Bengali text in
/// exported PDFs breaks without this step. Kalpurush + Roboto fallback are
/// used so Bangla and Latin text both render correctly.
class PdfRasterText {
  PdfRasterText({this.scale = 3});

  /// Render scale to keep exported text crisp.
  ///
  /// Logical points map 1:1 to PDF points; a scale of 3 gives ~216 DPI.
  final double scale;

  final Map<String, _Raster> _cache = <String, _Raster>{};

  static const _fontFamily = 'Kalpurush';
  static const _fallbackFamily = <String>['Roboto'];

  String _key(
    String text,
    double fontSize,
    bool bold,
    ui.Color color,
    double width,
    int? maxLines,
  ) =>
      '$text\u0001$fontSize\u0001$bold\u0001${color.toARGB32()}\u0001$width\u0001$maxLines';

  /// Layouts [text] wrapped at [width] logical points and rasterizes the
  /// glyphs. Must be called for every string that will be rendered with
  /// [build] later (the PDF layout phase is synchronous).
  Future<void> prepare(
    String text, {
    required double fontSize,
    required bool bold,
    required ui.Color color,
    required double width,
    ui.TextAlign textAlign = ui.TextAlign.left,
    int? maxLines,
  }) async {
    if (text.isEmpty) return;
    final key = _key(text, fontSize, bold, color, width, maxLines);
    if (_cache.containsKey(key)) return;

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: _fontFamily,
          fontFamilyFallback: _fallbackFamily,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: color,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: textAlign,
      maxLines: maxLines,
      ellipsis: maxLines != null ? '…' : null,
    )..layout(minWidth: width, maxWidth: width);

    final wPt = painter.width > width ? width : painter.width;
    final hPt = painter.height;
    final wPx = (wPt * scale).round().clamp(1, 1 << 15);
    final hPx = ((hPt * scale).round()).clamp(1, 1 << 15);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.scale(scale);
    painter.paint(canvas, ui.Offset.zero);
    painter.dispose();

    final image = await recorder.endRecording().toImage(wPx, hPx);
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    image.dispose();

    _cache[key] =
        _Raster(byteData!.buffer.asUint8List(), wPx, hPx, wPx / scale, hPx / scale);
  }

  /// Emits the prerendered text as an [pw.Image]. [pdfDocument] is any open
  /// document (e.g. `pwDocument.document`); images can be created eagerly
  /// before layout starts.
  pw.Widget build(
    PdfDocument pdfDocument,
    String text, {
    required double fontSize,
    required bool bold,
    required ui.Color color,
    required double width,
    pw.Alignment alignment = pw.Alignment.centerLeft,
    int? maxLines,
  }) {
    if (text.isEmpty) return pw.SizedBox(width: width, height: fontSize);
    final key = _key(text, fontSize, bold, color, width, maxLines);
    final r = _cache[key];
    if (r == null) return pw.SizedBox(width: width, height: fontSize);
    return pw.Image(
      pw.ImageProxy(
        PdfImage(
          pdfDocument,
          image: r.bytes,
          width: r.pxW,
          height: r.pxH,
        ),
      ),
      width: r.ptW,
      height: r.ptH,
      fit: pw.BoxFit.fill,
      alignment: alignment,
    );
  }
}

/// Brand column (company name, tagline, address, phone, email) rendered with
/// the raster text shaper so Bangla company/address text stays correct.
pw.Widget buildRasterCompanyColumn(
  PdfDocument pdfDocument,
  PdfRasterText raster,
  DocCompany company,
) {
  const indigo = ui.Color(0xFF1E3A8A);
  const grey600 = ui.Color(0xFF525252);
  const grey500 = ui.Color(0xFF737373);
  return pw.Column(
    mainAxisAlignment: pw.MainAxisAlignment.start,
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      raster.build(pdfDocument, company.name,
          fontSize: 20, bold: true, color: indigo, width: 300),
      pw.SizedBox(height: 3),
      raster.build(pdfDocument, company.tagline,
          fontSize: 9, bold: false, color: grey600, width: 300),
      pw.SizedBox(height: 6),
      if (company.address.isNotEmpty)
        raster.build(pdfDocument, company.address,
            fontSize: 8, bold: false, color: grey500, width: 300),
      if (company.phone.isNotEmpty)
        raster.build(pdfDocument, company.phone,
            fontSize: 8, bold: false, color: grey500, width: 300),
      if (company.email.isNotEmpty)
        raster.build(pdfDocument, company.email,
            fontSize: 8, bold: false, color: grey500, width: 300),
    ],
  );
}