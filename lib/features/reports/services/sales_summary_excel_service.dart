import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/services/download_export_service.dart';
import '../models/daily_sales.dart';

class SalesSummaryExcelService {
  final _downloadExportService = DownloadExportService();

  Future<File> saveSalesSummary({
    required List<DailySales> days,
    required DateTimeRange range,
  }) async {
    if (days.isEmpty) {
      throw StateError('No data in the selected period');
    }
    final fileName = 'sales-summary-${_rangeFilePart(range)}.xlsx';
    final bytes = buildWorkbook(days, range);
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

  Uint8List buildWorkbook(List<DailySales> days, DateTimeRange range) {
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
          _worksheetXml(days, range).length,
          utf8.encode(_worksheetXml(days, range)),
        ),
      );

    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  String _worksheetXml(List<DailySales> days, DateTimeRange range) {
    final rows = <String>[];
    var rowIndex = 1;
    final total = days.fold<double>(0, (sum, day) => sum + day.amount);
    final transactions = days.fold<int>(
      0,
      (sum, day) => sum + day.transactionCount,
    );
    final average = transactions > 0 ? total / transactions : 0.0;
    final lastDataRow = days.isEmpty ? 8 : 8 + days.length;
    final rangeText =
        '${DateFormat('dd MMM yyyy').format(range.start)} - ${DateFormat('dd MMM yyyy').format(range.end)}';

    rows.add(_row(rowIndex++, [_textCell('A1', 'Sales Summary', styleId: 1)]));
    rows.add(
      _row(rowIndex++, [
        _textCell('A2', 'Period', styleId: 2),
        _textCell('B2', rangeText, styleId: 3),
      ]),
    );
    rows.add(_row(rowIndex++, []));
    rows.add(
      _row(rowIndex++, [
        _textCell('A4', 'Total Sales', styleId: 4),
        _textCell('B4', _fmt(total), styleId: 5),
        _textCell('C4', 'Transactions', styleId: 4),
        _textCell('D4', '$transactions', styleId: 5),
      ]),
    );
    rows.add(
      _row(rowIndex++, [
        _textCell('A5', 'Average Order', styleId: 4),
        _textCell('B5', _fmt(average), styleId: 5),
        _textCell('C5', 'Days', styleId: 4),
        _textCell('D5', '${days.length}', styleId: 5),
      ]),
    );
    rows.add(_row(rowIndex++, []));
    rows.add(
      _row(rowIndex++, [
        _textCell('A8', 'Date', styleId: 6),
        _textCell('B8', 'Transactions', styleId: 6),
        _textCell('C8', 'Average Order', styleId: 6),
        _textCell('D8', 'Amount (৳)', styleId: 6),
      ]),
    );

    var dataRow = 9;
    for (final day in days) {
      final style = dataRow.isOdd ? 7 : 8;
      rows.add(
        _row(dataRow, [
          _textCell(
            'A$dataRow',
            DateFormat('dd MMM yyyy').format(day.date),
            styleId: style,
          ),
          _numberCell(
            'B$dataRow',
            day.transactionCount.toDouble(),
            styleId: style,
          ),
          _numberCell('C$dataRow', day.average, styleId: style),
          _numberCell('D$dataRow', day.amount, styleId: style),
        ]),
      );
      dataRow++;
    }

    rows.add(
      _row(dataRow, [
        _textCell('A$dataRow', 'TOTAL', styleId: 9),
        _textCell('B$dataRow', '', styleId: 9),
        _textCell('C$dataRow', '', styleId: 9),
        _numberCell('D$dataRow', total, styleId: 9),
      ]),
    );
    dataRow++;
    rows.add(_row(dataRow++, []));
    rows.add(
      _row(dataRow, [
        _textCell(
          'A$dataRow',
          'Generated by Mohajon on ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
          styleId: 10,
        ),
      ]),
    );

    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetViews>
    <sheetView workbookViewId="0"/>
  </sheetViews>
  <sheetFormatPr defaultRowHeight="15"/>
  <cols>
    <col min="1" max="1" width="18" customWidth="1"/>
    <col min="2" max="2" width="18" customWidth="1"/>
    <col min="3" max="3" width="20" customWidth="1"/>
    <col min="4" max="4" width="16" customWidth="1"/>
  </cols>
  <sheetData>
    ${rows.join()}
  </sheetData>
  <mergeCells count="3">
    <mergeCell ref="A1:D1"/>
    <mergeCell ref="A2:D2"/>
    <mergeCell ref="A${dataRow}:D${dataRow}"/>
  </mergeCells>
  <autoFilter ref="A8:D${lastDataRow}"/>
</worksheet>
''';
  }

  String _fmt(double v) => '৳ ${NumberFormat('#,##0.00').format(v)}';

  String _rangeFilePart(DateTimeRange range) =>
      '${DateFormat('yyyy-MM-dd').format(range.start)}-to-${DateFormat('yyyy-MM-dd').format(range.end)}';

  String _row(int index, List<String> cells) =>
      '<row r="$index">${cells.join()}</row>';

  String _textCell(String ref, String value, {int? styleId}) {
    final style = styleId == null ? '' : ' s="$styleId"';
    return '<c r="$ref"$style t="inlineStr"><is><t>${_escapeXml(value)}</t></is></c>';
  }

  String _numberCell(String ref, double value, {int? styleId}) {
    final style = styleId == null ? '' : ' s="$styleId"';
    return '<c r="$ref"$style><v>${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)}</v></c>';
  }

  String _escapeXml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  Future<Directory> _downloadDirectory() async {
    if (Platform.isAndroid) {
      final downloads = Directory('/storage/emulated/0/Download');
      if (await downloads.exists()) return downloads;
    }
    return getApplicationDocumentsDirectory();
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
    <sheet name="Sales Summary" sheetId="1" r:id="rId1"/>
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
    <font><b/><sz val="16"/><color rgb="FFFFFFFF"/><name val="Calibri"/><family val="2"/></font>
    <font><sz val="10"/><color rgb="FF64748B"/><name val="Calibri"/><family val="2"/></font>
    <font><b/><sz val="11"/><color rgb="FF1F2937"/><name val="Calibri"/><family val="2"/></font>
    <font><sz val="11"/><color rgb="FF1F2937"/><name val="Calibri"/><family val="2"/></font>
    <font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/><family val="2"/></font>
  </fonts>
  <fills count="6">
    <fill><patternFill patternType="none"/></fill>
    <fill><patternFill patternType="gray125"/></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FF1E3A8A"/><bgColor indexed="64"/></patternFill></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FFF8FAFC"/><bgColor indexed="64"/></patternFill></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FFE2E8F0"/><bgColor indexed="64"/></patternFill></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FFFFF4EB"/><bgColor indexed="64"/></patternFill></fill>
  </fills>
  <borders count="2">
    <border><left/><right/><top/><bottom/><diagonal/></border>
    <border><left style="thin"><color rgb="FFD1D5DB"/></left><right style="thin"><color rgb="FFD1D5DB"/></right><top style="thin"><color rgb="FFD1D5DB"/></top><bottom style="thin"><color rgb="FFD1D5DB"/></bottom><diagonal/></border>
  </borders>
  <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
  <cellXfs count="11">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
    <xf numFmtId="0" fontId="0" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>
    <xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>
    <xf numFmtId="0" fontId="2" fillId="3" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"/>
    <xf numFmtId="0" fontId="3" fillId="4" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"/>
    <xf numFmtId="0" fontId="4" fillId="5" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>
    <xf numFmtId="0" fontId="4" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>
    <xf numFmtId="0" fontId="3" fillId="3" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"/>
    <xf numFmtId="0" fontId="3" fillId="4" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"/>
    <xf numFmtId="0" fontId="2" fillId="5" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="right" vertical="center"/></xf>
    <xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>
  </cellXfs>
  <cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
</styleSheet>
''';
