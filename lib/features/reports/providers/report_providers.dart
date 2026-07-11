import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/customer.dart';
import '../../../core/models/ledger_entry.dart' as core;
import '../../../core/models/payment.dart';
import '../../../core/models/product.dart';
import '../../../core/models/sale.dart';
import '../../customers/providers/customer_providers.dart';
import '../../products/providers/product_providers.dart';
import '../models/customer_ledger.dart';
import '../models/ledger_entry.dart';

final customerLedgerListProvider = Provider<List<CustomerLedger>>((ref) {
  final customers = ref.watch(customersProvider).value ?? const <Customer>[];
  final sales = ref.watch(salesStreamProvider).value ?? const <Sale>[];
  final payments = ref.watch(paymentsStreamProvider).value ?? const <Payment>[];

  double maxAmount = 0;
  final result = customers.map((customer) {
    final customerSales = sales
        .where((s) => s.customerId == customer.customerId)
        .toList();
    final customerPayments = payments
        .where((p) => p.customerId == customer.customerId)
        .toList();
    final debit = customerSales.fold<double>(
      0,
      (sum, s) => sum + s.totalAmount,
    );
    final credit = customerPayments.fold<double>(
      0,
      (sum, p) => sum + p.amount,
    );
    if (debit > maxAmount) maxAmount = debit;
    if (credit > maxAmount) maxAmount = credit;
    return CustomerLedger(
      customerId: customer.customerId,
      name: customer.name,
      phone: customer.phone,
      debit: debit,
      credit: credit,
    );
  }).toList();

  return result.map((c) {
    return CustomerLedger(
      customerId: c.customerId,
      name: c.name,
      phone: c.phone,
      debit: c.debit,
      credit: c.credit,
      maxAmount: maxAmount,
    );
  }).toList();
});

final customerLedgerDetailProvider =
    Provider.family<List<LedgerEntry>, String>((ref, customerId) {
  final entries = ref.watch(customerLedgerProvider(customerId));
  double balance = 0;
  return entries.map((e) {
    balance += e.signedAmount;
    return LedgerEntry(
      date: e.createdAt,
      particulars: e.description,
      debit: e.isDebit ? e.amount : 0,
      credit: e.isCredit ? e.amount : 0,
      balance: balance,
    );
  }).toList();
});

enum InventoryStatus { normal, low, outOfStock }

class InventoryReport {
  final List<Product> products;
  final int totalItems;
  final double totalStockValue;
  final int lowStockCount;
  final int outOfStockCount;

  InventoryReport({
    required this.products,
    required this.totalItems,
    required this.totalStockValue,
    required this.lowStockCount,
    required this.outOfStockCount,
  });
}

final inventoryReportProvider = Provider<InventoryReport>((ref) {
  final products = ref.watch(productsProvider).value ?? const <Product>[];
  final totalItems = products.length;
  final totalStockValue = products.fold<double>(
    0,
    (s, p) => s + (p.stockQty * p.purchasePrice),
  );
  final lowStockCount = products.where((p) => p.isLowStock && p.stockQty > 0).length;
  final outOfStockCount = products.where((p) => p.stockQty <= 0).length;
  return InventoryReport(
    products: products,
    totalItems: totalItems,
    totalStockValue: totalStockValue,
    lowStockCount: lowStockCount,
    outOfStockCount: outOfStockCount,
  );
});

InventoryStatus inventoryStatus(Product p) {
  if (p.stockQty <= 0) return InventoryStatus.outOfStock;
  if (p.isLowStock) return InventoryStatus.low;
  return InventoryStatus.normal;
}
