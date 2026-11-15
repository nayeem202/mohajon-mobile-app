import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/download_export_service.dart';
import '../../../core/services/pdf_doc.dart';
import '../../reports/models/table_report.dart';
import '../../reports/services/report_table_pdf.dart';
import '../../reports/services/report_table_xlsx.dart';
import '../presentation/accounting_widgets.dart';

ReportTableData accountingReportTable(
  Map<String, dynamic> report,
  AppLocalizations l10n, {
  required bool balanceSheet,
}) {
  final rows = <Map<String, Object?>>[];
  if (balanceSheet) {
    for (final section in ['assets', 'liabilities', 'equity']) {
      rows.add({
        'item': l10n.t(
          'acct${section[0].toUpperCase()}${section.substring(1)}',
        ),
        'amount': '',
      });
      for (final row
          in (report[section] as List? ?? const []).whereType<Map>()) {
        rows.add({
          'item': l10n.t('acctAccount${row['account']}'),
          'amount': accountingNumber(row['amount']),
        });
      }
    }
    for (final key in [
      'totalAssets',
      'totalLiabilities',
      'totalEquity',
      'difference',
    ]) {
      rows.add({
        'item': l10n.t('acct${key[0].toUpperCase()}${key.substring(1)}'),
        'amount': accountingNumber(report[key]),
      });
    }
  } else {
    for (final key in incomeMetrics) {
      rows.add({
        'item': l10n.t(metricKey(key)),
        'amount': accountingNumber(report[key]),
      });
    }
  }
  if (report['_cached'] == true) {
    rows.add({'item': l10n.t('acctCached'), 'amount': ''});
  }
  if (report['isLocalEstimate'] == true) {
    rows.add({'item': l10n.t('acctLocalHelp'), 'amount': ''});
  }
  if (report['rangeAdjusted'] == true) {
    rows.add({'item': l10n.t('acctRangeAdjusted'), 'amount': ''});
  }
  if (accountingNumber(report['_pending']) > 0) {
    rows.add({
      'item': l10n.tP('acctPending', {'count': '${report['_pending']}'}),
      'amount': '',
    });
  }
  for (final issue
      in (report['issues'] as List? ?? const []).whereType<Map>()) {
    final key = 'acctIssue${issue['code']}';
    final text = l10n.t(key);
    rows.add({
      'item': text == key ? l10n.t('acctReviewUnderlying') : text,
      'amount': '',
    });
  }
  rows.add({'item': l10n.t('acctExportWarning'), 'amount': ''});
  return ReportTableData(
    title: l10n.t(balanceSheet ? 'acctBalance' : 'acctIncome'),
    subtitle:
        '${balanceSheet ? '${l10n.t('acctAsOf')}: ${report['asOf']}' : '${report['from']} — ${report['to']}'}\n${l10n.t('branches')}: ${report['branchId'] ?? ''}\n${l10n.t('acctSnapshot')}: ${report['generatedAt'] ?? ''}',
    columns: [
      ReportTableColumn(key: 'item', header: l10n.t('description'), weight: 3),
      ReportTableColumn(
        key: 'amount',
        header: l10n.t('acctAmount'),
        rightAlign: true,
      ),
    ],
    rows: rows,
  );
}

Future<String> saveAccountingExport(
  ReportTableData table,
  DocCompany company, {
  required bool pdf,
  required bool balanceSheet,
}) async {
  final Uint8List bytes = pdf
      ? await buildTablePdf(table, company)
      : buildTableXlsx(table);
  final stamp = DateTime.now().toIso8601String().replaceAll(
    RegExp(r'[^0-9]'),
    '',
  );
  final name =
      '${balanceSheet ? 'balance-sheet' : 'income-statement'}-$stamp.${pdf ? 'pdf' : 'xlsx'}';
  final saved = await DownloadExportService().saveFileToDownloads(
    fileName: name,
    mimeType: pdf
        ? 'application/pdf'
        : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    bytes: bytes,
  );
  if (saved != null) return saved;
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/$name');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
