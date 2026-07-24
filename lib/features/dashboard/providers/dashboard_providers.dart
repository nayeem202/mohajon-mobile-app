import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/customer.dart';
import '../../../core/models/customer_ledger_entry.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/product.dart';
import '../../../core/models/sale.dart';
import '../../../features/customers/providers/customer_providers.dart';
import '../../../features/products/providers/product_providers.dart';
import '../../../features/vendors/providers/vendor_providers.dart';

final dashboardProvider = Provider<DashboardSummary>((ref) {
  final products = ref.watch(productsProvider).value ?? const <Product>[];
  final customers = ref.watch(customersProvider).value ?? const <Customer>[];
  final sales = ref.watch(salesStreamProvider).value ?? const <Sale>[];
  final payments = ref.watch(paymentsStreamProvider).value ?? const <Payment>[];
  final ledgerEntries =
      ref.watch(customerLedgerEntriesStreamProvider).value ??
      const <CustomerLedgerEntry>[];
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final todayEnd = todayStart.add(const Duration(days: 1));

  final todaySales = sales
      .where(
        (sale) =>
            !sale.createdAt.isBefore(todayStart) &&
            sale.createdAt.isBefore(todayEnd),
      )
      .fold<double>(0, (sum, sale) => sum + sale.totalAmount);

  final todayTransactionCount = sales
      .where(
        (sale) =>
            !sale.createdAt.isBefore(todayStart) &&
            sale.createdAt.isBefore(todayEnd),
      )
      .length;

  final yesterdayStart = todayStart.subtract(const Duration(days: 1));
  final yesterdaySales = sales
      .where(
        (sale) =>
            !sale.createdAt.isBefore(yesterdayStart) &&
            sale.createdAt.isBefore(todayStart),
      )
      .fold<double>(0, (sum, sale) => sum + sale.totalAmount);

  final unlinkedPayments = payments.where((payment) => payment.saleId == null);
  final totalDue =
      sales.fold<double>(0, (sum, sale) => sum + sale.dueAmount) -
      unlinkedPayments.fold<double>(0, (sum, payment) => sum + payment.amount) +
      ledgerEntries.fold<double>(0, (sum, entry) => sum + entry.signedAmount);

  final grossProfit = sales.fold<double>(
    0,
    (sum, sale) => sum + (sale.profit > 0 ? sale.profit : 0),
  );
  final grossLoss = sales.fold<double>(
    0,
    (sum, sale) => sum + (sale.profit < 0 ? sale.profit.abs() : 0),
  );
  final vendorExpenses = ref.watch(vendorTotalExpenseProvider);
  final netProfit = grossProfit - grossLoss - vendorExpenses;
  final profitLossRatio = grossLoss == 0
      ? (grossProfit == 0 ? 0.0 : double.infinity)
      : grossProfit / grossLoss;

  final customerDueCount = customers.where((customer) {
    final customerSales = sales.where(
      (sale) => sale.customerId == customer.customerId,
    );
    final customerPayments = payments.where(
      (payment) =>
          payment.customerId == customer.customerId && payment.saleId == null,
    );
    final customerLedgerAdjustments = ledgerEntries.where(
      (entry) => entry.customerId == customer.customerId,
    );
    final due =
        customerSales.fold<double>(0, (sum, sale) => sum + sale.dueAmount) -
        customerPayments.fold<double>(
          0,
          (sum, payment) => sum + payment.amount,
        ) +
        customerLedgerAdjustments.fold<double>(
          0,
          (sum, entry) => sum + entry.signedAmount,
        );
    return due > 0;
  }).length;

  final customerById = {
    for (final customer in customers) customer.customerId: customer,
  };
  final sortedSales = [...sales]
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  final productSoldQty = <String, double>{};
  for (final sale in sales) {
    for (final item in sale.items) {
      productSoldQty[item.name] = (productSoldQty[item.name] ?? 0) + item.qty;
    }
  }
  final topSelling = productSoldQty.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final lowStock = products.where((product) => product.isLowStock).toList();

  final monthlySales = List<double>.filled(12, 0);
  for (final sale in sales.where((sale) => sale.createdAt.year == now.year)) {
    monthlySales[sale.createdAt.month - 1] += sale.totalAmount;
  }

  final dayWiseSales = List<DaySalesSummary>.generate(7, (index) {
    final day = todayStart.subtract(Duration(days: 6 - index));
    final dayEnd = day.add(const Duration(days: 1));
    final dayTotal = sales
        .where(
          (sale) =>
              !sale.createdAt.isBefore(day) && sale.createdAt.isBefore(dayEnd),
        )
        .fold<double>(0, (sum, sale) => sum + sale.totalAmount);
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return DaySalesSummary(
      label: labels[day.weekday - 1],
      date: day,
      sales: dayTotal,
      isToday:
          day.year == todayStart.year &&
          day.month == todayStart.month &&
          day.day == todayStart.day,
    );
  });

  return DashboardSummary(
    todaySales: todaySales,
    todayTransactionCount: todayTransactionCount,
    yesterdaySales: yesterdaySales,
    totalDue: totalDue,
    customerDueCount: customerDueCount,
    totalStock: products.fold<int>(
      0,
      (sum, product) => sum + product.stockQty,
    ).toDouble(),
    customerCount: customers.length,
    grossProfit: grossProfit,
    grossLoss: grossLoss,
    netProfit: netProfit,
    profitLossRatio: profitLossRatio,
    topSelling: topSelling
        .take(3)
        .map(
          (entry) => TopSellingProduct(name: entry.key, quantity: entry.value),
        )
        .toList(),
    recentSales: sortedSales.take(6).map((sale) {
      final customer = customerById[sale.customerId];
      return RecentSaleSummary(
        invoiceNo:
            '#INV-${sale.saleId.substring(0, sale.saleId.length < 6 ? sale.saleId.length : 6).toUpperCase()}',
        customerName: customer?.name.isNotEmpty == true
            ? customer!.name
            : 'Walk-in customer',
        itemCount: sale.items.fold<int>(
          0,
          (sum, item) => sum + item.qty.round(),
        ),
        amount: sale.totalAmount,
        dueAmount: sale.dueAmount,
        createdAt: sale.createdAt,
      );
    }).toList(),
    lowStock: lowStock,
    dayWiseSales: dayWiseSales,
    monthlySales: monthlySales,
  );
});

class DashboardSummary {
  const DashboardSummary({
    required this.todaySales,
    required this.todayTransactionCount,
    required this.yesterdaySales,
    required this.totalDue,
    required this.customerDueCount,
    required this.totalStock,
    required this.customerCount,
    required this.grossProfit,
    required this.grossLoss,
    required this.netProfit,
    required this.profitLossRatio,
    required this.topSelling,
    required this.recentSales,
    required this.lowStock,
    required this.dayWiseSales,
    required this.monthlySales,
  });

  final double todaySales;
  final int todayTransactionCount;
  final double yesterdaySales;
  final double totalDue;
  final int customerDueCount;
  final double totalStock;
  final int customerCount;
  final double grossProfit;
  final double grossLoss;
  final double netProfit;
  final double profitLossRatio;
  final List<TopSellingProduct> topSelling;
  final List<RecentSaleSummary> recentSales;
  final List<Product> lowStock;
  final List<DaySalesSummary> dayWiseSales;
  final List<double> monthlySales;
}

class RecentSaleSummary {
  const RecentSaleSummary({
    required this.invoiceNo,
    required this.customerName,
    required this.itemCount,
    required this.amount,
    required this.dueAmount,
    required this.createdAt,
  });

  final String invoiceNo;
  final String customerName;
  final int itemCount;
  final double amount;
  final double dueAmount;
  final DateTime createdAt;

  bool get isPaid => dueAmount <= 0;
}

class TopSellingProduct {
  const TopSellingProduct({required this.name, required this.quantity});

  final String name;
  final double quantity;
}

class DaySalesSummary {
  const DaySalesSummary({
    required this.label,
    required this.date,
    required this.sales,
    required this.isToday,
  });

  final String label;
  final DateTime date;
  final double sales;
  final bool isToday;
}
