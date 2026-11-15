import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_1/core/localization/accounting_localizations.dart';
import 'package:inventory_1/core/localization/app_localizations.dart';
import 'package:inventory_1/core/models/sale.dart';
import 'package:inventory_1/core/models/sale_return.dart';
import 'package:inventory_1/features/accounting/domain/local_income_statement.dart';
import 'package:inventory_1/features/accounting/data/accounting_export.dart';
import 'package:inventory_1/features/accounting/presentation/accounting_widgets.dart';
import 'package:inventory_1/features/reports/services/report_table_xlsx.dart';
import 'package:inventory_1/features/reports/services/report_table_pdf.dart';
import 'package:inventory_1/core/services/pdf_doc.dart';

final _date = DateTime(2026, 10, 2);
Sale invoice({
  double total = 198,
  double? original = 198,
  String branch = 's-main',
  bool deleted = false,
}) => Sale(
  saleId: 'sale',
  customerId: 'customer',
  items: const [
    SaleItem(
      saleItemId: 'i',
      productId: 'p',
      name: 'Rice',
      qty: 2,
      unitPrice: 100,
      purchasePrice: 60,
    ),
  ],
  totalAmount: total,
  originalTotalAmount: original,
  initialPaidAmount: 198,
  initialPaymentId: 'payment',
  discount: 20,
  vatPercent: 10,
  paidAmount: total,
  dueAmount: 0,
  paymentStatus: PaymentStatus.paid,
  shopId: 's',
  branchId: branch,
  createdAt: _date,
  updatedAt: _date,
  isDeleted: deleted,
);
SaleReturn returned() => SaleReturn(
  returnId: 'r',
  saleId: 'sale',
  customerId: 'customer',
  items: const [
    SaleReturnItem(
      returnItemId: 'ri',
      saleItemId: 'i',
      productId: 'p',
      name: 'Rice',
      qty: 1,
      unitPrice: 100,
      purchasePrice: 60,
    ),
  ],
  refundAmount: 99,
  refundMethod: 'CASH',
  reason: 'Return',
  staffId: null,
  branchId: 's-main',
  shopId: 's',
  createdAt: DateTime(2026, 11, 1),
  updatedAt: DateTime(2026, 11, 1),
);
Map<String, dynamic> statement(
  List<Sale> sales,
  List<SaleReturn> returns, {
  int month = 10,
}) => localIncomeStatement(
  sales: sales,
  returns: returns,
  expenses: [],
  shopId: 's',
  branchId: 's-main',
  from: DateTime(2026, month),
  to: DateTime(2026, month + 1, 0),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('income excludes VAT, applies discount and recorded cost', () {
    final result = statement([invoice()], []);
    expect(result['salesRevenue'], 180);
    expect(result['costOfGoodsSold'], 120);
    expect(result['netProfit'], 60);
    expect(result['isLocalEstimate'], true);
    expect(result['requiresReview'], true);
  });
  test('return on later date does not rewrite original invoice period', () {
    final original = invoice(total: 99, original: null);
    final october = statement([original], [returned()]);
    final november = statement([original], [returned()], month: 11);
    expect(october['salesRevenue'], 180);
    expect(october['salesReturns'], 0);
    expect(october['netProfit'], 60);
    expect(november['salesRevenue'], 0);
    expect(november['salesReturns'], 90);
    expect(november['costOfGoodsSold'], -60);
    expect(november['netProfit'], -30);
  });
  test('deleted and other branch invoices never enter local statement', () {
    expect(
      statement([
        invoice(branch: 'other'),
        invoice(deleted: true),
      ], [])['netProfit'],
      0,
    );
  });
  test('orphan return is a quality issue, not invented zero-cost income', () {
    final report = statement([], [returned()], month: 11);
    expect(
      (report['issues'] as List).any(
        (row) => row['code'] == 'RETURN_SOURCE_MISSING',
      ),
      true,
    );
  });
  test('immutable original payment evidence survives sync and return copy', () {
    final sale = Sale.fromJson(
      invoice().copyWith(totalAmount: 99, paidAmount: 99).toJson(),
    );
    expect(sale.originalTotalAmount, 198);
    expect(sale.initialPaidAmount, 198);
    expect(sale.initialPaymentId, 'payment');
  });
  test(
    'accounting catalogue has matching BN/EN keys and all account/type labels',
    () {
      expect(accountingBangla.keys.toSet(), accountingEnglish.keys.toSet());
      for (final code in openingAccounts) {
        expect(
          accountingEnglish.containsKey('acctAccount$code'),
          true,
          reason: code,
        );
      }
      for (final code in financeEntryTypes) {
        expect(
          accountingBangla.containsKey('acctType$code'),
          true,
          reason: code,
        );
      }
      for (final metric in incomeMetrics) {
        expect(
          accountingEnglish.containsKey(metricKey(metric)),
          true,
          reason: metric,
        );
      }
    },
  );
  test('amount parser accepts Bengali digits and rejects nonfinite values', () {
    expect(parseAccountingAmount('১,২৩৪.৫০'), 1234.5);
    expect(parseAccountingAmount('NaN'), null);
    expect(parseAccountingAmount('Infinity'), null);
  });
  for (final locale in ['en', 'bn']) {
    test(
      'financial PDF renders full statement with bilingual quality notes in $locale',
      () async {
        final report = statement([invoice()], []);
        final table = accountingReportTable(
          report,
          AppLocalizations(Locale(locale)),
          balanceSheet: false,
        );
        final bytes = await buildTablePdf(
          table,
          const DocCompany(name: 'মহাজন স্টোর'),
        );
        expect(String.fromCharCodes(bytes.take(4)), '%PDF');
        expect(bytes.length, greaterThan(1000));
      },
    );
    test('statement and workbook retain complete Unicode XML in $locale', () {
      final l10n = AppLocalizations(Locale(locale));
      final table = accountingReportTable(
        statement([invoice()], []),
        l10n,
        balanceSheet: false,
      );
      expect(table.title, l10n.t('acctIncome'));
      expect(
        table.rows.any((row) => row['item'] == l10n.t('acctLocalHelp')),
        true,
      );
      final archive = ZipDecoder().decodeBytes(buildTableXlsx(table));
      final sheet = utf8.decode(
        archive.findFile('xl/worksheets/sheet1.xml')!.content as List<int>,
      );
      final workbook = utf8.decode(
        archive.findFile('xl/workbook.xml')!.content as List<int>,
      );
      expect(sheet.trim().endsWith('</worksheet>'), true);
      expect(workbook.trim().endsWith('</workbook>'), true);
      expect(sheet, contains(l10n.t('acctMetricNetProfit')));
      expect(sheet, contains(l10n.t('acctExportWarning')));
    });
  }
}
