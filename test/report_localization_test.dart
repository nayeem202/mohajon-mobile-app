import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_1/core/localization/app_localizations.dart';
import 'package:inventory_1/core/services/pdf_doc.dart';
import 'package:inventory_1/features/reports/models/table_report.dart';
import 'package:inventory_1/features/reports/services/report_table_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Bangla export localizes report metadata and preserves shop names', () {
    const table = ReportTableData(
      title: 'Due Payments',
      subtitle: 'All time',
      summaries: [ReportSummary(label: 'Total Due', value: '৳1,250')],
      columns: [ReportTableColumn(key: 'name', header: 'Customer')],
      rows: [
        {'name': 'প্রাণ টমেটো সস'},
      ],
    );

    final localized = localizedReportTable(
      table,
      AppLocalizations(const Locale('bn')),
    );

    expect(localized.title, 'বকেয়া আদায়');
    expect(localized.subtitle, 'সর্বমোট সময়');
    expect(localized.summaries.single.label, 'মোট বকেয়া');
    expect(localized.columns.single.header, 'কাস্টমার');
    expect(localized.rows.single['name'], 'প্রাণ টমেটো সস');
  });

  test('English export keeps its English metadata', () {
    const table = ReportTableData(
      title: 'Due Payments',
      subtitle: 'All time',
      columns: [ReportTableColumn(key: 'name', header: 'Customer')],
      rows: [],
    );

    final localized = localizedReportTable(
      table,
      AppLocalizations(const Locale('en')),
    );

    expect(localized.title, table.title);
    expect(localized.columns.single.header, 'Customer');
  });

  test(
    'PDF export rasterizes Bengali metadata and customer/product text',
    () async {
      const table = ReportTableData(
        title: 'বকেয়া আদায়',
        subtitle: 'সর্বমোট সময়',
        summaries: [ReportSummary(label: 'মোট বকেয়া', value: '৳১,২৫০')],
        columns: [ReportTableColumn(key: 'name', header: 'কাস্টমার')],
        rows: [
          {'name': 'প্রাণ টমেটো সস'},
        ],
      );

      final pdf = await buildTablePdf(
        table,
        const DocCompany(name: 'মহাজন স্টোর'),
      );

      expect(String.fromCharCodes(pdf.take(4)), '%PDF');
    },
  );
}
