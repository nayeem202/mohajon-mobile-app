import 'dart:convert';

import '../../../core/offline/local_database.dart';
import '../../expenses/models/expense.dart';

/// Builds a compact JSON snapshot of the shop's current business state from
/// offline Hive data. Sent along with HamBot questions so the AI can answer
/// with real numbers ("total due", "today's sales", "low stock", top debtors).
class HamBotStats {
  const HamBotStats._();

  static String build(LocalDatabase db, {String? shopId}) {
    final products = db.products.values();
    final customers = db.customers.values();
    final sales = db.sales.values();
    final payments = db.payments.values();
    final ledger = db.customerLedgerEntries.values();

    DateTime? nowDt;
    try {
      nowDt = DateTime.now();
    } catch (_) {}
    final now = nowDt ?? DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final thirtyDaysStart = todayStart.subtract(const Duration(days: 30));

    double sumOf(Iterable<dynamic> items, double Function(dynamic) f) =>
        items.fold<double>(0, (s, item) => s + f(item));

    final totProd = products.length;
    final totCust = customers.length;

    final todaySales = sumOf(
      sales.where(
        (s) =>
            !s.createdAt.isBefore(todayStart) && s.createdAt.isBefore(todayEnd),
      ),
      (s) => s.totalAmount,
    );
    final todayPaid = sumOf(
      sales.where(
        (s) =>
            !s.createdAt.isBefore(todayStart) && s.createdAt.isBefore(todayEnd),
      ),
      (s) => s.paidAmount,
    );
    final yesterdaySales = sumOf(
      sales.where(
        (s) =>
            !s.createdAt.isBefore(yesterdayStart) &&
            s.createdAt.isBefore(todayStart),
      ),
      (s) => s.totalAmount,
    );
    final todayExpenses = sumOf(
      db.expenses.values().where(
        (e) => !e.date.isBefore(todayStart) && e.date.isBefore(todayEnd),
      ),
      (e) => (e as Expense).amount,
    );
    final expenses30d = db.expenses
        .values()
        .where((e) => !e.date.isBefore(thirtyDaysStart))
        .toList();
    final expenses30dTotal = sumOf(expenses30d, (e) => (e as Expense).amount);

    final soldByProduct = <String, Map<String, Object>>{};
    for (final sale in sales.where(
      (s) => !s.createdAt.isBefore(thirtyDaysStart) && !s.isDeleted,
    )) {
      for (final item in sale.items) {
        final entry = soldByProduct.putIfAbsent(
          item.productId,
          () => {'name': item.name, 'qty': 0.0, 'sales_taka': 0.0},
        );
        entry['qty'] = (entry['qty'] as double) + item.qty;
        entry['sales_taka'] = (entry['sales_taka'] as double) + item.lineTotal;
      }
    }
    final topSellingProducts = soldByProduct.values.toList()
      ..sort((a, b) => (b['qty'] as double).compareTo(a['qty'] as double));
    final inventorySnapshot = products
        .where((p) => !p.isDeleted)
        .take(20)
        .map(
          (p) => {
            'name': p.nameEn,
            'stock': p.stockQty,
            'selling_price': p.sellingPrice,
            'buying_price': p.buyingPrice,
            'category': p.category,
            'expiry': p.expiryDate?.toIso8601String(),
          },
        )
        .toList();

    final totalDue =
        sumOf(sales, (s) => s.dueAmount) -
        sumOf(payments.where((p) => p.saleId == null), (p) => p.amount) +
        sumOf(ledger, (l) => l.signedAmount);

    final lowStock = products.where((p) => p.isLowStock).toList();
    final lowStockNames = lowStock.take(5).map((p) => p.nameEn).toList();

    final lowStockCount = products.where((p) => p.isLowStock).length;

    final debtors = <Map<String, Object>>[];
    for (final customer in customers) {
      final csales = sales.where((s) => s.customerId == customer.customerId);
      final cpay = payments.where(
        (p) => p.customerId == customer.customerId && p.saleId == null,
      );
      final cledger = ledger.where((l) => l.customerId == customer.customerId);
      final due =
          sumOf(csales, (s) => s.dueAmount) -
          sumOf(cpay, (p) => p.amount) +
          sumOf(cledger, (l) => l.signedAmount);
      if (due > 0) {
        debtors.add({'name': customer.name, 'due': (due * 100).round() / 100});
      }
    }
    debtors.sort((a, b) => (b['due'] as num).compareTo(a['due'] as num));
    final topDebtors = debtors.take(5).toList();

    return jsonEncode({
      'today_sales_taka': (todaySales * 100).round() / 100,
      'today_paid_taka': (todayPaid * 100).round() / 100,
      'yesterday_sales_taka': (yesterdaySales * 100).round() / 100,
      'today_expenses_taka': (todayExpenses * 100).round() / 100,
      'expenses_last_30d_taka': (expenses30dTotal * 100).round() / 100,
      'today_gross_profit_taka':
          (sales
                      .where(
                        (s) =>
                            !s.createdAt.isBefore(todayStart) &&
                            s.createdAt.isBefore(todayEnd),
                      )
                      .fold<double>(0, (sum, sale) => sum + sale.profit) *
                  100)
              .round() /
          100,
      'total_due_taka': (totalDue * 100).round() / 100,
      'total_customers': totCust,
      'total_products': totProd,
      'customers_with_due': topDebtors,
      'customer_due_count': debtors.length,
      'low_stock_items': lowStockNames,
      'low_stock_count': lowStockCount,
      'top_selling_products_last_30d': topSellingProducts.take(10).toList(),
      'inventory_snapshot': inventorySnapshot,
      'shop_id': shopId ?? '',
    });
  }
}
