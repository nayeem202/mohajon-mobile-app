import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/models/product.dart';
import '../../../core/services/download_export_service.dart';
import '../providers/report_providers.dart';

class InventoryExcelService {
  final _downloadExportService = DownloadExportService();

  Future<File> saveInventoryReport(InventoryReport report) async {
    final bytes = buildInventoryWorkbook(report);
    final fileName = 'inventory-report.xlsx';
    return _saveFile(fileName, bytes);
  }

  Future<File> _saveFile(String fileName, Uint8List bytes) async {
    final androidSavedPath = await _downloadExportService.saveFileToDownloads(
      fileName: fileName,
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      bytes: bytes,
    );
    if (androidSavedPath != null) {
      return File(androidSavedPath);
    }
    final directory = await _downloadDirectory();
    try {
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } on FileSystemException {
      final fallback = await getApplicationDocumentsDirectory();
      final file = File('${fallback.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      return file;
    }
  }

  Uint8List buildInventoryWorkbook(InventoryReport report) {
    final archive = Archive()
      ..addFile(ArchiveFile('[Content_Types].xml',
          _contentTypesXml.length, utf8.encode(_contentTypesXml)))
      ..addFile(ArchiveFile(
          '_rels/.rels', _rootRelationshipsXml.length, utf8.encode(_rootRelationshipsXml)))
      ..addFile(ArchiveFile('xl/workbook.xml',
          _workbookXml.length, utf8.encode(_workbookXml)))
      ..addFile(ArchiveFile('xl/_rels/workbook.xml.rels',
          _workbookRelationshipsXml.length, utf8.encode(_workbookRelationshipsXml)))
      ..addFile(ArchiveFile('xl/styles.xml',
          _sharedStylesXml.length, utf8.encode(_sharedStylesXml)))
      ..addFile(ArchiveFile('xl/worksheets/sheet1.xml',
          _sheetXml(report).length, utf8.encode(_sheetXml(report))));
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  String _sheetXml(InventoryReport report) {
    final rows = <String>[];
    var r = 1;
    double totalValue = 0;

    rows.add(_row(r++, [_textCell('A$r', 'Inventory Report', styleId: 1)]));
    rows.add(_row(r++, [_textCell('A$r', _periodText(), styleId: 2)]));
    rows.add(_row(r++, []));
    rows.add(_row(r++, [_textCell('A$r', 'Total Items', styleId: 3), _textCell('B$r', '${report.totalItems}', styleId: 4)]));
    rows.add(_row(r++, [_textCell('A$r', 'Stock Value', styleId: 3), _textCell('B$r', _fmt(report.totalStockValue), styleId: 4)]));
    rows.add(_row(r++, [_textCell('A$r', 'Low Stock Items', styleId: 3), _textCell('B$r', '${report.lowStockCount}', styleId: 4)]));
    rows.add(_row(r++, [_textCell('A$r', 'Out of Stock', styleId: 3), _textCell('B$r', '${report.outOfStockCount}', styleId: 4)]));
    rows.add(_row(r++, []));
    rows.add(_row(r, [
      _textCell('A$r', '#', styleId: 5),
      _textCell('B$r', 'Product Name', styleId: 5),
      _textCell('C$r', 'Category', styleId: 5),
      _textCell('D$r', 'Stock Qty', styleId: 5),
      _textCell('E$r', 'Low Alert', styleId: 5),
      _textCell('F$r', 'Purchase Price', styleId: 5),
      _textCell('G$r', 'Stock Value', styleId: 5),
      _textCell('H$r', 'Status', styleId: 5),
    ]));
    r++;
    final headerRow = r - 1;

    for (var i = 0; i < report.products.length; i++) {
      final p = report.products[i];
      final status = inventoryStatus(p);
      final statusLabel = status == InventoryStatus.outOfStock
          ? 'Out of Stock'
          : status == InventoryStatus.low
              ? 'Low'
              : 'Normal';
      final stockValue = p.stockQty * p.purchasePrice;
      totalValue += stockValue;
      final style = r.isOdd ? 6 : 7;
      rows.add(_row(r, [
        _textCell('A$r', '${i + 1}', styleId: style),
        _textCell('B$r', p.nameEn.isEmpty ? p.nameBn : p.nameEn, styleId: style),
        _textCell('C$r', p.category.isEmpty ? 'Uncategorized' : p.category, styleId: style),
        _numberCell('D$r', p.stockQty, styleId: style),
        _numberCell('E$r', p.lowStockAlert, styleId: style),
        _numberCell('F$r', p.purchasePrice, styleId: style),
        _numberCell('G$r', stockValue, styleId: style),
        _textCell('H$r', statusLabel, styleId: style),
      ]));
      r++;
    }

    final lastDataRow = r - 1;
    rows.add(_row(r, [
      _textCell('A$r', 'TOTAL', styleId: 8),
      _textCell('B$r', '', styleId: 8),
      _textCell('C$r', '', styleId: 8),
      _textCell('D$r', '', styleId: 8),
      _textCell('E$r', '', styleId: 8),
      _textCell('F$r', '', styleId: 8),
      _numberCell('G$r', totalValue, styleId: 8),
      _textCell('H$r', '', styleId: 8),
    ]));
    r++;
    rows.add(_row(r++, []));
    rows.add(_row(r, [
      _textCell('A$r', 'Generated by Haalkhata on ${DateFormat('dd MMM yyyy').format(DateTime.now())}', styleId: 9),
    ]));

    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetViews><sheetView workbookViewId="0"/></sheetViews>
  <sheetFormatPr defaultRowHeight="15"/>
  <cols>
    <col min="1" max="1" width="5" customWidth="1"/>
    <col min="2" max="2" width="25" customWidth="1"/>
    <col min="3" max="3" width="15" customWidth="1"/>
    <col min="4" max="5" width="12" customWidth="1"/>
    <col min="6" max="6" width="16" customWidth="1"/>
    <col min="7" max="7" width="16" customWidth="1"/>
    <col min="8" max="8" width="14" customWidth="1"/>
  </cols>
  <sheetData>${rows.join()}</sheetData>
  <mergeCells count="2">
    <mergeCell ref="A1:H$headerRow"/>
    <mergeCell ref="A${lastDataRow + 2}:H${lastDataRow + 2}"/>
  </mergeCells>
</worksheet>''';
  }

  String _periodText() => 'As of ${DateFormat('MMMM d, yyyy').format(DateTime.now())}';
  String _fmt(double v) => '৳ ${_formatNumber(v)}';
  String _formatNumber(double v) => NumberFormat('#,##0').format(v);

  String _row(int index, List<String> cells) =>
      '<row r="$index">${cells.join()}</row>';

  String _textCell(String ref, String value, {int? styleId}) {
    final s = styleId == null ? '' : ' s="$styleId"';
    return '<c r="$ref"$s t="inlineStr"><is><t>${_e(value)}</t></is></c>';
  }

  String _numberCell(String ref, num value, {int? styleId}) {
    final s = styleId == null ? '' : ' s="$styleId"';
    final v = value is double ? value.toStringAsFixed(value % 1 == 0 ? 0 : 2) : value.toString();
    return '<c r="$ref"$s><v>$v</v></c>';
  }

  String _e(String v) => v
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  Future<Directory> _downloadDirectory() async {
    if (Platform.isAndroid) {
      final d = Directory('/storage/emulated/0/Download');
      if (await d.exists()) return d;
    }
    return getApplicationDocumentsDirectory();
  }
}

const _contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
</Types>''';

const _rootRelationshipsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''';

const _workbookXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets><sheet name="Inventory" sheetId="1" r:id="rId1"/></sheets>
</workbook>''';

const _workbookRelationshipsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';

const _sharedStylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="5">
    <font><b/><sz val="16"/><color rgb="FFFFFFFFFF"/><name val="Calibri"/><family val="2"/></font>
    <font><sz val="10"/><color rgb="FF64748B"/><name val="Calibri"/><family val="2"/></font>
    <font><b/><sz val="11"/><color rgb="FF1F2937"/><name val="Calibri"/><family val="2"/></font>
    <font><sz val="11"/><color rgb="FF1F2937"/><name val="Calibri"/><family val="2"/></font>
    <font><b/><sz val="11"/><color rgb="FFFFFFFFFF"/><name val="Calibri"/><family val="2"/></font>
  </fonts>
  <fills count="6">
    <fill><patternFill patternType="none"/></fill>
    <fill><patternFill patternType="gray125"/></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FF1E3A8A"/><bgColor indexed="64"/></patternFill></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FFE2E8F0"/><bgColor indexed="64"/></patternFill></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FFF8FAFC"/><bgColor indexed="64"/></patternFill></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FF1E3A8A"/><bgColor indexed="64"/></patternFill></fill>
  </fills>
  <borders count="2">
    <border><left/><right/><top/><bottom/><diagonal/></border>
    <border><left style="thin"><color rgb="FFD1D5DB"/></left><right style="thin"><color rgb="FFD1D5DB"/></right><top style="thin"><color rgb="FFD1D5DB"/></top><bottom style="thin"><color rgb="FFD1D5DB"/></bottom><diagonal/></border>
  </borders>
  <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
  <cellXfs count="10">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
    <xf numFmtId="0" fontId="0" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>
    <xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>
    <xf numFmtId="0" fontId="2" fillId="3" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"/>
    <xf numFmtId="0" fontId="3" fillId="4" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"/>
    <xf numFmtId="0" fontId="4" fillId="5" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>
    <xf numFmtId="0" fontId="3" fillId="3" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"/>
    <xf numFmtId="0" fontId="3" fillId="4" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"/>
    <xf numFmtId="0" fontId="2" fillId="0" borderId="1" xfId="0" applyFont="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>
    <xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>
  </cellXfs>
  <cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
</styleSheet>''';
