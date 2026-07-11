import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/services/download_export_service.dart';
import '../models/customer_ledger.dart';
import '../models/ledger_entry.dart';

class LedgerExcelService {
  final _downloadExportService = DownloadExportService();

  Future<File> saveAllCustomers(List<CustomerLedger> customers) async {
    final bytes = buildAllCustomersWorkbook(customers);
    final fileName = 'customer-ledger-all.xlsx';
    return _saveFile(fileName, bytes);
  }

  Future<File> saveCustomerDetail(
    CustomerLedger customer,
    List<LedgerEntry> entries,
  ) async {
    final bytes = buildCustomerDetailWorkbook(customer, entries);
    final fileName =
        'ledger-${_safeFilePart(customer.name.isEmpty ? 'customer' : customer.name)}.xlsx';
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

  Uint8List buildAllCustomersWorkbook(List<CustomerLedger> customers) {
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
          _allCustomersSheetXml(customers).length, utf8.encode(_allCustomersSheetXml(customers))));
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  Uint8List buildCustomerDetailWorkbook(
    CustomerLedger customer,
    List<LedgerEntry> entries,
  ) {
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
          _detailSheetXml(customer, entries).length, utf8.encode(_detailSheetXml(customer, entries))));
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  String _allCustomersSheetXml(List<CustomerLedger> customers) {
    final rows = <String>[];
    var r = 1;
    final totalOutstanding =
        customers.fold<double>(0, (s, c) => s + c.balance);
    final withDues = customers.where((c) => c.hasDue).length;

    rows.add(_row(r++, [_textCell('A$r', 'Customer Ledger — All Customers', styleId: 1)]));
    rows.add(_row(r++, [_textCell('A$r', _periodText(), styleId: 2)]));
    rows.add(_row(r++, []));
    rows.add(_row(r++, [_textCell('A$r', 'Total Customers', styleId: 3), _textCell('B$r', '${customers.length}', styleId: 4)]));
    rows.add(_row(r++, [_textCell('A$r', 'Total Outstanding', styleId: 3), _textCell('B$r', _fmt(totalOutstanding), styleId: 4)]));
    rows.add(_row(r++, [_textCell('A$r', 'Customers with Dues', styleId: 3), _textCell('B$r', '$withDues', styleId: 4)]));
    rows.add(_row(r++, []));
    rows.add(_row(r++, [
      _textCell('A$r', 'Customer Name', styleId: 5),
      _textCell('B$r', 'Phone Number', styleId: 5),
      _textCell('C$r', 'Debit (DR)', styleId: 5),
      _textCell('D$r', 'Credit (CR)', styleId: 5),
      _textCell('E$r', 'Closing Balance', styleId: 5),
      _textCell('F$r', 'Status', styleId: 5),
    ]));
    final headerRow = r - 1;

    for (final c in customers) {
      final settled = !c.hasDue;
      final style = r.isOdd ? 6 : 7;
      rows.add(_row(r, [
        _textCell('A$r', c.name, styleId: style),
        _textCell('B$r', c.phone, styleId: style),
        _numberCell('C$r', c.debit, styleId: style),
        _numberCell('D$r', c.credit, styleId: style),
        _numberCell('E$r', c.balance, styleId: style),
        _textCell('F$r', settled ? 'Settled' : 'Due', styleId: style),
      ]));
      r++;
    }

    final lastDataRow = r - 1;
    rows.add(_row(r++, []));
    rows.add(_row(r, [
      _textCell('A$r', 'Generated by Haalkhata on ${DateFormat('dd MMM yyyy').format(DateTime.now())}', styleId: 9),
    ]));

    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetViews><sheetView workbookViewId="0"/></sheetViews>
  <sheetFormatPr defaultRowHeight="15"/>
  <cols>
    <col min="1" max="1" width="25" customWidth="1"/>
    <col min="2" max="2" width="21" customWidth="1"/>
    <col min="3" max="3" width="17" customWidth="1"/>
    <col min="4" max="5" width="17" customWidth="1"/>
    <col min="6" max="6" width="12" customWidth="1"/>
  </cols>
  <sheetData>${rows.join()}</sheetData>
  <mergeCells count="2">
    <mergeCell ref="A1:F$headerRow"/>
    <mergeCell ref="A${lastDataRow + 2}:F${lastDataRow + 2}"/>
  </mergeCells>
</worksheet>''';
  }

  String _detailSheetXml(CustomerLedger customer, List<LedgerEntry> entries) {
    final rows = <String>[];
    var r = 1;
    final totalDebit = entries.fold<double>(0, (s, e) => s + e.debit);
    final totalCredit = entries.fold<double>(0, (s, e) => s + e.credit);
    final lastBalance = entries.isEmpty ? 0.0 : entries.last.balance;

    rows.add(_row(r++, [_textCell('A$r', 'Customer Ledger — ${customer.name}', styleId: 1)]));
    rows.add(_row(r++, [_textCell('A$r', _periodText(), styleId: 2)]));
    rows.add(_row(r++, []));
    rows.add(_row(r++, [_textCell('A$r', 'Customer Name', styleId: 3), _textCell('B$r', customer.name, styleId: 4)]));
    rows.add(_row(r++, [_textCell('A$r', 'Phone', styleId: 3), _textCell('B$r', customer.phone, styleId: 4)]));
    rows.add(_row(r++, []));
    rows.add(_row(r++, [_textCell('A$r', 'Opening', styleId: 3), _textCell('B$r', _fmt(0), styleId: 4)]));
    rows.add(_row(r++, [_textCell('A$r', 'Total Debit', styleId: 3), _textCell('B$r', _fmt(totalDebit), styleId: 4)]));
    rows.add(_row(r++, [_textCell('A$r', 'Total Credit', styleId: 3), _textCell('B$r', _fmt(totalCredit), styleId: 4)]));
    rows.add(_row(r++, [_textCell('A$r', 'Closing Balance', styleId: 3), _textCell('B$r', _fmt(lastBalance), styleId: 4)]));
    rows.add(_row(r++, []));
    rows.add(_row(r, [
      _textCell('A$r', 'Date', styleId: 5),
      _textCell('B$r', 'Particulars', styleId: 5),
      _textCell('C$r', 'Debit (DR)', styleId: 5),
      _textCell('D$r', 'Credit (CR)', styleId: 5),
      _textCell('E$r', 'Balance', styleId: 5),
    ]));
    r++;
    final headerRow = r - 1;

    for (final entry in entries) {
      final style = r.isOdd ? 6 : 7;
      final dateStr = DateFormat('MMM d, y').format(entry.date);
      rows.add(_row(r, [
        _textCell('A$r', dateStr, styleId: style),
        _textCell('B$r', entry.particulars, styleId: style),
        _numberCell('C$r', entry.debit, styleId: style),
        _numberCell('D$r', entry.credit, styleId: style),
        _numberCell('E$r', entry.balance, styleId: style),
      ]));
      r++;
    }

    final lastDataRow = r - 1;
    rows.add(_row(r, [
      _textCell('A$r', 'TOTAL', styleId: 8),
      _textCell('B$r', '', styleId: 8),
      _numberCell('C$r', totalDebit, styleId: 8),
      _numberCell('D$r', totalCredit, styleId: 8),
      _numberCell('E$r', lastBalance, styleId: 8),
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
    <col min="1" max="1" width="18" customWidth="1"/>
    <col min="2" max="2" width="30" customWidth="1"/>
    <col min="3" max="5" width="17" customWidth="1"/>
  </cols>
  <sheetData>${rows.join()}</sheetData>
  <mergeCells count="2">
    <mergeCell ref="A1:E$headerRow"/>
    <mergeCell ref="A${lastDataRow + 3}:E${lastDataRow + 3}"/>
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

  String _numberCell(String ref, double value, {int? styleId}) {
    final s = styleId == null ? '' : ' s="$styleId"';
    final v = value.toStringAsFixed(value % 1 == 0 ? 0 : 2);
    return '<c r="$ref"$s><v>$v</v></c>';
  }

  String _e(String v) => v
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  String _safeFilePart(String v) => v
      .trim()
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '')
      .toLowerCase();

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
  <sheets><sheet name="Ledger" sheetId="1" r:id="rId1"/></sheets>
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
