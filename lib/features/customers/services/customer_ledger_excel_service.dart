import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/models/customer.dart';
import '../../../core/models/ledger_entry.dart';
import '../../../core/services/download_export_service.dart';

class CustomerLedgerExcelService {
  final _downloadExportService = DownloadExportService();

  Future<File> saveToDownloads(
    Customer customer,
    List<LedgerEntry> ledger,
  ) async {
    final bytes = buildWorkbook(customer, ledger);
    final fileName =
        'ledger-${_safeFilePart(customer.name.isEmpty ? 'customer' : customer.name)}.xlsx';
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
      return _writeLedgerFile(directory, fileName, bytes);
    } on FileSystemException {
      final fallback = await getApplicationDocumentsDirectory();
      return _writeLedgerFile(fallback, fileName, bytes);
    }
  }

  Uint8List buildWorkbook(Customer customer, List<LedgerEntry> ledger) {
    final archive = Archive()
      ..addFile(
        ArchiveFile(
          '[Content_Types].xml',
          _contentTypesXml.length,
          utf8.encode(_contentTypesXml),
        ),
      )
      ..addFile(
        ArchiveFile(
          '_rels/.rels',
          _rootRelationshipsXml.length,
          utf8.encode(_rootRelationshipsXml),
        ),
      )
      ..addFile(
        ArchiveFile(
          'xl/workbook.xml',
          _workbookXml.length,
          utf8.encode(_workbookXml),
        ),
      )
      ..addFile(
        ArchiveFile(
          'xl/_rels/workbook.xml.rels',
          _workbookRelationshipsXml.length,
          utf8.encode(_workbookRelationshipsXml),
        ),
      )
      ..addFile(
        ArchiveFile(
          'xl/styles.xml',
          _stylesXml.length,
          utf8.encode(_stylesXml),
        ),
      )
      ..addFile(
        ArchiveFile(
          'xl/worksheets/sheet1.xml',
          _worksheetXml(customer, ledger).length,
          utf8.encode(_worksheetXml(customer, ledger)),
        ),
      );

    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  Future<File> _writeLedgerFile(
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

  String _worksheetXml(Customer customer, List<LedgerEntry> ledger) {
    final rows = <String>[];
    var rowIndex = 1;
    var runningBalance = 0.0;
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final lastLedgerRow = ledger.isEmpty ? 6 : 6 + ledger.length;

    rows.add(_row(rowIndex++, [
      _textCell('A1', 'Customer Ledger', styleId: 1),
    ]));
    rows.add(_row(rowIndex++, [
      _textCell('A2', 'Customer Name', styleId: 2),
      _textCell('B2', customer.name, styleId: 3),
    ]));
    rows.add(_row(rowIndex++, [
      _textCell('A3', 'Phone', styleId: 2),
      _textCell('B3', customer.phone, styleId: 3),
    ]));
    rows.add(_row(rowIndex++, [
      _textCell('A4', 'Exported At', styleId: 2),
      _textCell('B4', dateFormat.format(DateTime.now()), styleId: 3),
    ]));
    rows.add(_row(rowIndex++, []));
    rows.add(_row(rowIndex++, [
      _textCell('A6', 'Date', styleId: 4),
      _textCell('B6', 'Particulars', styleId: 4),
      _textCell('C6', 'Debit (৳)', styleId: 4),
      _textCell('D6', 'Credit (৳)', styleId: 4),
      _textCell('E6', 'Balance (৳)', styleId: 4),
    ]));

    for (final entry in ledger) {
      runningBalance += entry.signedAmount;
      final debit = entry.isDebit ? entry.amount : 0.0;
      final credit = entry.isCredit ? entry.amount : 0.0;
      final textStyleId = rowIndex.isOdd ? 5 : 7;
      final numberStyleId = rowIndex.isOdd ? 6 : 8;
      rows.add(_row(rowIndex, [
        _textCell(
          'A$rowIndex',
          dateFormat.format(entry.createdAt.toLocal()),
          styleId: textStyleId,
        ),
        _textCell(
          'B$rowIndex',
          '${_entryTypeLabel(entry.type)} — ${entry.description}',
          styleId: textStyleId,
        ),
        _numberCell('C$rowIndex', debit, styleId: numberStyleId),
        _numberCell('D$rowIndex', credit, styleId: numberStyleId),
        _numberCell('E$rowIndex', runningBalance, styleId: numberStyleId),
      ]));
      rowIndex++;
    }

    rows.add(_row(rowIndex++, []));
    rows.add(_row(rowIndex, [
      _textCell(
        'A$rowIndex',
        'Generated by Mohajon on ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
        styleId: 9,
      ),
    ]));

    return '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetViews>
    <sheetView workbookViewId="0"/>
  </sheetViews>
  <sheetFormatPr defaultRowHeight="15"/>
  <cols>
    <col min="1" max="1" width="20" customWidth="1"/>
    <col min="2" max="2" width="34" customWidth="1"/>
    <col min="3" max="5" width="17" customWidth="1"/>
  </cols>
  <sheetData>
    ${rows.join()}
  </sheetData>
  <mergeCells count="2">
    <mergeCell ref="A1:E1"/>
    <mergeCell ref="A$rowIndex:E$rowIndex"/>
  </mergeCells>
  <autoFilter ref="A6:E$lastLedgerRow"/>
</worksheet>
''';
  }

  String _row(int rowIndex, List<String> cells) {
    return '<row r="$rowIndex">${cells.join()}</row>';
  }

  String _textCell(String ref, String value, {int? styleId}) {
    final styleAttr = styleId == null ? '' : ' s="$styleId"';
    return '<c r="$ref"$styleAttr t="inlineStr"><is><t>${_escapeXml(value)}</t></is></c>';
  }

  String _numberCell(String ref, double value, {int? styleId}) {
    final styleAttr = styleId == null ? '' : ' s="$styleId"';
    if (value == 0) return '<c r="$ref"$styleAttr><v>0</v></c>';
    return '<c r="$ref"$styleAttr><v>${value.toStringAsFixed(2)}</v></c>';
  }

  String _entryTypeLabel(LedgerEntryType type) {
    return switch (type) {
      LedgerEntryType.sale => 'Sale',
      LedgerEntryType.payment => 'Payment',
      LedgerEntryType.debit => 'Debit',
      LedgerEntryType.credit => 'Credit',
    };
  }

  String _safeFilePart(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '')
        .toLowerCase();
  }

  String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}

const String _contentTypesXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
</Types>
''';

const String _rootRelationshipsXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>
''';

const String _workbookXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="Ledger" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>
''';

const String _workbookRelationshipsXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>
''';

const String _stylesXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="5">
    <font>
      <sz val="11"/>
      <color rgb="FF1F2937"/>
      <name val="Calibri"/>
      <family val="2"/>
    </font>
    <font>
      <b/>
      <sz val="18"/>
      <color rgb="FFFFFFFF"/>
      <name val="Calibri"/>
      <family val="2"/>
    </font>
    <font>
      <b/>
      <sz val="11"/>
      <color rgb="FF0F172A"/>
      <name val="Calibri"/>
      <family val="2"/>
    </font>
    <font>
      <b/>
      <sz val="11"/>
      <color rgb="FFFFFFFF"/>
      <name val="Calibri"/>
      <family val="2"/>
    </font>
    <font>
      <sz val="11"/>
      <color rgb="FF0F172A"/>
      <name val="Calibri"/>
      <family val="2"/>
    </font>
  </fonts>
  <fills count="6">
    <fill>
      <patternFill patternType="none"/>
    </fill>
    <fill>
      <patternFill patternType="gray125"/>
    </fill>
    <fill>
      <patternFill patternType="solid">
        <fgColor rgb="FF0F766E"/>
        <bgColor indexed="64"/>
      </patternFill>
    </fill>
    <fill>
      <patternFill patternType="solid">
        <fgColor rgb="FFE2E8F0"/>
        <bgColor indexed="64"/>
      </patternFill>
    </fill>
    <fill>
      <patternFill patternType="solid">
        <fgColor rgb="FF1D4ED8"/>
        <bgColor indexed="64"/>
      </patternFill>
    </fill>
    <fill>
      <patternFill patternType="solid">
        <fgColor rgb="FFF8FAFC"/>
        <bgColor indexed="64"/>
      </patternFill>
    </fill>
  </fills>
  <borders count="2">
    <border>
      <left/>
      <right/>
      <top/>
      <bottom/>
      <diagonal/>
    </border>
    <border>
      <left style="thin"><color rgb="FFD1D5DB"/></left>
      <right style="thin"><color rgb="FFD1D5DB"/></right>
      <top style="thin"><color rgb="FFD1D5DB"/></top>
      <bottom style="thin"><color rgb="FFD1D5DB"/></bottom>
      <diagonal/>
    </border>
  </borders>
  <cellStyleXfs count="1">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
  </cellStyleXfs>
  <cellXfs count="9">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
    <xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1" applyAlignment="1">
      <alignment horizontal="center" vertical="center"/>
    </xf>
    <xf numFmtId="0" fontId="2" fillId="3" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"/>
    <xf numFmtId="0" fontId="4" fillId="5" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"/>
    <xf numFmtId="0" fontId="3" fillId="4" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1">
      <alignment horizontal="center" vertical="center"/>
    </xf>
    <xf numFmtId="0" fontId="4" fillId="5" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"/>
    <xf numFmtId="4" fontId="4" fillId="5" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyNumberFormat="1"/>
    <xf numFmtId="0" fontId="4" fillId="0" borderId="1" xfId="0" applyFont="1" applyBorder="1"/>
    <xf numFmtId="4" fontId="4" fillId="0" borderId="1" xfId="0" applyFont="1" applyBorder="1" applyNumberFormat="1"/>
    <xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>
  </cellXfs>
  <cellStyles count="1">
    <cellStyle name="Normal" xfId="0" builtinId="0"/>
  </cellStyles>
</styleSheet>
''';
