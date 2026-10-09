import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../config/app_config.dart';
import '../constants/app_constants.dart';
import '../models/shop_profile.dart';

class DocCompany {
  const DocCompany({
    required this.name,
    this.tagline = 'Smart POS & Inventory Management',
    this.address = '',
    this.phone = '',
    this.email = '',
    this.tin = '',
    this.bin = '',
    this.logoBytes,
  });

  final String name;
  final String tagline;
  final String address;
  final String phone;
  final String email;
  final String tin;
  final String bin;
  final Uint8List? logoBytes;

  factory DocCompany.fromShop(ShopProfile? shop) => DocCompany(
        name: (shop?.shopName ?? '').trim().isEmpty
            ? AppConstants.appName
            : shop!.shopName.trim(),
        tagline: 'Smart POS & Inventory Management',
        address: (shop?.location ?? '').trim(),
        phone: (shop?.phoneNumber ?? '').trim(),
        email: (shop?.ownerEmail ?? '').trim(),
        tin: (shop?.tin ?? '').trim(),
        bin: (shop?.bin ?? '').trim(),
      );

  /// Best-effort logo loading keeps exports reliable even while offline. A
  /// report still exports normally when the logo cannot be downloaded.
  static Future<DocCompany> fromShopForExport(ShopProfile? shop) async {
    final base = DocCompany.fromShop(shop);
    final path = (shop?.reportLogoPath ?? '').trim();
    if (path.isEmpty) return base;
    final url = path.startsWith('http://') || path.startsWith('https://')
        ? path
        : '${AppConfig.apiBaseUrl}$path';
    try {
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 8),
      );
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          response.bodyBytes.isNotEmpty) {
        return DocCompany(
          name: base.name,
          tagline: base.tagline,
          address: base.address,
          phone: base.phone,
          email: base.email,
          tin: base.tin,
          bin: base.bin,
          logoBytes: response.bodyBytes,
        );
      }
    } catch (_) {
      // Exporting data is more important than a temporarily unavailable logo.
    }
    return base;
  }
}

pw.Font? _baseFont;
pw.Font? _boldFont;

/// Noto Sans Bengali is embedded in every exported PDF. This is important for
/// thermal receipts because printer/PDF viewers do not have access to the
/// app's Flutter font files at render time.
Future<pw.ThemeData> buildAppPdfTheme() async {
  if (_baseFont == null) {
    final regular = await rootBundle.load(
      'assets/fonts/NotoSansBengali-Regular.ttf',
    );
    _baseFont = pw.Font.ttf(regular);
  }
  if (_boldFont == null) {
    final bold = await rootBundle.load(
      'assets/fonts/NotoSansBengali-Bold.ttf',
    );
    _boldFont = pw.Font.ttf(bold);
  }
  return pw.ThemeData.withFont(base: _baseFont!, bold: _boldFont!);
}

/// Left-side brand/company column shown at the top of every exported page.
/// Uses the shop's own name, address and phone from the owner profile instead
/// of placeholder data.
pw.Widget buildCompanyColumn(DocCompany company) {
  final details = pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        company.name,
        style: pw.TextStyle(
          fontSize: 20,
          fontWeight: pw.FontWeight.bold,
          color: const PdfColor.fromInt(0xFF1E3A8A),
        ),
      ),
      pw.Text(
        company.tagline,
        style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
      ),
      pw.SizedBox(height: 6),
      if (company.address.isNotEmpty)
        pw.Text(
          company.address,
          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
        ),
      if (company.phone.isNotEmpty)
        pw.Text(
          company.phone,
          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
        ),
      if (company.email.isNotEmpty)
        pw.Text(
          company.email,
          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
        ),
      if (company.tin.isNotEmpty) pw.Text('TIN: ${company.tin}', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
      if (company.bin.isNotEmpty) pw.Text('BIN: ${company.bin}', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
    ],
  );
  if (company.logoBytes == null) return details;
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        width: 46,
        height: 46,
        padding: const pw.EdgeInsets.all(2),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Image(pw.MemoryImage(company.logoBytes!), fit: pw.BoxFit.contain),
      ),
      pw.SizedBox(width: 9),
      pw.Expanded(child: details),
    ],
  );
}
