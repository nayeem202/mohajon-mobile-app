import '../../../core/models/sale.dart';
import '../../../core/models/sale_return.dart';
import '../../../core/utils/money.dart';
import '../../expenses/models/expense.dart';

/// A clearly labelled local estimate, also used by the existing P&L screen.
/// Original sales and returns belong to their own dates; output VAT is not
/// revenue, and a sale header reduced by returns is never subtracted twice.
Map<String, dynamic> localIncomeStatement({
  required Iterable<Sale> sales,
  required Iterable<SaleReturn> returns,
  required Iterable<Expense> expenses,
  required String shopId,
  required String branchId,
  required DateTime from,
  required DateTime to,
}) {
  final start = DateTime(from.year, from.month, from.day);
  final end = DateTime(to.year, to.month, to.day).add(const Duration(days: 1));
  bool inRange(DateTime date) => !date.isBefore(start) && date.isBefore(end);
  final scopedSales = sales
      .where(
        (s) =>
            !s.isDeleted &&
            s.shopId == shopId &&
            (s.branchId ?? '$shopId-main') == branchId,
      )
      .toList();
  final scopedReturns = returns
      .where(
        (r) => !r.isDeleted && r.shopId == shopId && r.branchId == branchId,
      )
      .toList();
  var revenue = 0.0, returnedRevenue = 0.0, cogs = 0.0, costReversed = 0.0;
  final warnings = <String>{'LOCAL_ESTIMATE'};
  for (final sale in scopedSales) {
    if (!inRange(sale.createdAt)) continue;
    final totalReturns = scopedReturns
        .where((r) => r.saleId == sale.saleId)
        .fold<double>(0, (sum, r) => sum + r.refundAmount);
    final original =
        sale.originalTotalAmount ??
        moneyRound2(sale.totalAmount + totalReturns);
    final vat = sale.invoiceTotals.vatAmount;
    if ((original - sale.invoiceTotals.total).abs() > 0.01) {
      warnings.add('INVOICE_TOTAL_MISMATCH');
    }
    revenue += moneyRound2(original - vat);
    cogs += sale.items.fold<double>(
      0,
      (sum, item) => sum + moneyRound2(item.qty * item.purchasePrice),
    );
  }
  for (final returned in scopedReturns.where((r) => inRange(r.createdAt))) {
    final sale = scopedSales
        .where((s) => s.saleId == returned.saleId)
        .firstOrNull;
    if (sale == null) {
      warnings.add('RETURN_SOURCE_MISSING');
      continue;
    }
    final totalReturns = scopedReturns
        .where((r) => r.saleId == sale.saleId)
        .fold<double>(0, (sum, r) => sum + r.refundAmount);
    final original =
        sale.originalTotalAmount ??
        moneyRound2(sale.totalAmount + totalReturns);
    final vatReversed = original <= 0
        ? 0.0
        : moneyRound2(
            returned.refundAmount * sale.invoiceTotals.vatAmount / original,
          );
    returnedRevenue += moneyRound2(returned.refundAmount - vatReversed);
    costReversed += returned.items.fold<double>(
      0,
      (sum, item) => sum + moneyRound2(item.qty * item.purchasePrice),
    );
  }
  final operatingExpenses = expenses
      .where(
        (e) =>
            !e.isDeleted &&
            e.shopId == shopId &&
            (e.branchId ?? '$shopId-main') == branchId &&
            inRange(e.date),
      )
      .fold<double>(0, (sum, e) => sum + e.amount);
  final netSales = moneyRound2(revenue - returnedRevenue);
  final netCogs = moneyRound2(cogs - costReversed);
  final gross = moneyRound2(netSales - netCogs);
  return {
    'configured': false,
    'isLocalEstimate': true,
    'generatedAt': DateTime.now().toIso8601String(),
    'requiresReview': true,
    'shopId': shopId,
    'branchId': branchId,
    'from': start.toIso8601String().substring(0, 10),
    'to': to.toIso8601String().substring(0, 10),
    'salesRevenue': moneyRound2(revenue),
    'salesReturns': moneyRound2(returnedRevenue),
    'netSales': netSales,
    'costOfGoodsSold': netCogs,
    'grossProfit': gross,
    'otherIncome': 0.0,
    'operatingExpenses': moneyRound2(operatingExpenses),
    'depreciation': 0.0,
    'interest': 0.0,
    'netProfit': moneyRound2(gross - operatingExpenses),
    'issues': [
      for (final warning in warnings)
        {
          'code': warning,
          'sourceType': 'LOCAL',
          'sourceId': '',
          'blocking': true,
          'choices': <String>[],
        },
    ],
  };
}
