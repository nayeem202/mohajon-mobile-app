import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../constants/app_constants.dart';
import '../models/shop_profile.dart';

class DocCompany {
  const DocCompany({
    required this.name,
    this.tagline = 'Smart POS & Inventory Management',
    this.address = '',
    this.phone = '',
    this.email = '',
  });

  final String name;
  final String tagline;
  final String address;
  final String phone;
  final String email;

  factory DocCompany.fromShop(ShopProfile? shop) => DocCompany(
        name: AppConstants.appName,
        tagline: 'Smart POS & Inventory Management',
        address: (shop?.location ?? '').trim(),
        phone: (shop?.phoneNumber ?? '').trim(),
        email: (shop?.ownerEmail ?? '').trim(),
      );
}

pw.Font? _baseFont;
pw.Font? _boldFont;

/// Bengali (Kalpurush) font is used for all exported PDFs so that Bangla
/// product/customer names render correctly without breaking glyphs.
Future<pw.ThemeData> buildAppPdfTheme() async {
  if (_baseFont == null) {
    final regular = await rootBundle.load('assets/fonts/Kalpurush-Regular.ttf');
    _baseFont = pw.Font.ttf(regular);
  }
  if (_boldFont == null) {
    final bold = await rootBundle.load('assets/fonts/Kalpurush-Regular.ttf');
    _boldFont = pw.Font.ttf(bold);
  }
  return pw.ThemeData.withFont(base: _baseFont!, bold: _boldFont!);
}

/// Left-side brand/company column shown at the top of every exported page.
/// Uses the shop's own name, address and phone from the owner profile instead
/// of placeholder data.
pw.Widget buildCompanyColumn(DocCompany company) {
  return pw.Column(
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
    ],
  );
}