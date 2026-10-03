import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/models/purchase.dart';
import '../../../core/models/sale.dart';
import '../../../core/models/product.dart';
import '../../../core/services/api_client.dart';
import '../../../core/utils/network_guard.dart';
import '../models/purchase_order.dart';

class PurchaseRecommendation {
  const PurchaseRecommendation({
    required this.product,
    required this.suggestedQty,
    required this.unitCost,
    required this.dailyVelocity,
    required this.coverageDays,
    required this.supplier,
  });

  final Product product;
  final double suggestedQty;
  final double unitCost;
  final double dailyVelocity;
  final double coverageDays;
  final Supplier? supplier;

  double get estimatedTotal => suggestedQty * unitCost;
  bool get needsPurchase => suggestedQty > 0;
}

class PurchasePlannerService {
  PurchasePlannerService(this._ref);

  final Ref _ref;

  ApiClient get _api => ApiClient(_ref.read(localDatabaseProvider));
  String get _shopId => _ref.read(shopIdProvider);

  List<PurchaseRecommendation> recommendations({
    required List<Product> products,
    required List<Sale> sales,
    required List<Purchase> purchases,
    required List<Supplier> suppliers,
    int lookbackDays = 30,
    int targetStockDays = 14,
    int leadTimeDays = 7,
  }) {
    final cutoff = DateTime.now().subtract(Duration(days: lookbackDays));
    final result = <PurchaseRecommendation>[];
    for (final product in products.where((item) => !item.isDeleted)) {
      final sold = sales
          .where((sale) => !sale.isDeleted && sale.createdAt.isAfter(cutoff))
          .expand((sale) => sale.items)
          .where((item) => item.productId == product.productId)
          .fold<double>(0, (sum, item) => sum + item.qty);
      final velocity = sold / lookbackDays;
      final reorderPoint = velocity * leadTimeDays + velocity * 3;
      final targetQty = velocity * targetStockDays;
      final suggested = (targetQty - product.stockQty).ceilToDouble();
      if (suggested <= 0 && product.stockQty > product.lowStockAlert) continue;

      final history = purchases
          .where((purchase) => !purchase.isDeleted)
          .expand((purchase) => purchase.items.map((item) => (purchase, item)))
          .where((pair) => pair.$2.productId == product.productId)
          .toList();
      final unitCost = history.isEmpty
          ? product.purchasePrice
          : history
                  .map((pair) => pair.$2.unitCost)
                  .reduce((a, b) => a + b) /
              history.length;
      final supplier = _bestSupplier(history, suppliers);
      final fallbackQty = product.stockQty <= product.lowStockAlert
          ? (reorderPoint - product.stockQty).clamp(1, double.infinity).toDouble()
          : suggested;
      result.add(
        PurchaseRecommendation(
          product: product,
          suggestedQty: fallbackQty.ceilToDouble(),
          unitCost: unitCost,
          dailyVelocity: velocity,
          coverageDays: velocity <= 0 ? double.infinity : product.stockQty / velocity,
          supplier: supplier,
        ),
      );
    }
    result.sort((a, b) => a.coverageDays.compareTo(b.coverageDays));
    return result;
  }

  Supplier? _bestSupplier(
    List<(Purchase, PurchaseItem)> history,
    List<Supplier> suppliers,
  ) {
    if (history.isEmpty) return suppliers.isEmpty ? null : suppliers.first;
    final counts = <String, int>{};
    for (final pair in history) {
      counts[pair.$1.supplierId] = (counts[pair.$1.supplierId] ?? 0) + 1;
    }
    final id = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return suppliers.where((supplier) => supplier.supplierId == id).firstOrNull;
  }

  double cashBudget({
    required List<Sale> sales,
    required List<dynamic> expenses,
  }) {
    final monthStart = DateTime(DateTime.now().year, DateTime.now().month);
    final inflow = sales
        .where((sale) => !sale.isDeleted && sale.createdAt.isAfter(monthStart))
        .fold<double>(0, (sum, sale) => sum + sale.paidAmount);
    final outflow = expenses
        .where((expense) => !expense.isDeleted && expense.date.isAfter(monthStart))
        .fold<double>(0, (sum, expense) => sum + expense.amount);
    return (inflow - outflow).clamp(0, double.infinity).toDouble();
  }

  Future<PurchaseOrder> createOrder({
    required List<PurchaseRecommendation> recommendations,
    required double budget,
    String notes = 'Created from Smart Purchase Planner',
  }) async {
    final selected = <PurchaseRecommendation>[];
    var remaining = budget;
    for (final item in recommendations) {
      if (!item.needsPurchase || item.unitCost <= 0) continue;
      final qty = remaining.isInfinite
          ? item.suggestedQty
          : (remaining / item.unitCost)
              .floorToDouble()
              .clamp(0, item.suggestedQty)
              .toDouble();
      if (qty <= 0) continue;
      selected.add(
        PurchaseRecommendation(
          product: item.product,
          suggestedQty: qty,
          unitCost: item.unitCost,
          dailyVelocity: item.dailyVelocity,
          coverageDays: item.coverageDays,
          supplier: item.supplier,
        ),
      );
      remaining -= qty * item.unitCost;
    }
    if (selected.isEmpty) throw StateError('No purchase item fits the cash budget.');
    final now = DateTime.now();
    final supplierId = selected.map((item) => item.supplier?.supplierId).whereType<String>().firstOrNull ?? '';
    final order = PurchaseOrder(
      orderId: const Uuid().v4(),
      supplierId: supplierId,
      items: selected
          .map((item) => PurchaseOrderItem(
                productId: item.product.productId,
                name: item.product.nameEn,
                qty: item.suggestedQty,
                unitCost: item.unitCost,
                batchNumber: item.product.batchNumber,
                expiryDate: item.product.expiryDate,
              ))
          .toList(),
      totalAmount: selected.fold<double>(0, (sum, item) => sum + item.estimatedTotal),
      status: 'DRAFT',
      notes: notes,
      shopId: _shopId,
      branchId: _ref.read(localDatabaseProvider).settings.get('activeBranchId') as String? ?? '$_shopId-main',
      createdAt: now,
      updatedAt: now,
    );
    await _ref.read(localDatabaseProvider).purchaseOrders.put(order);
    await _push(order);
    return order;
  }

  Future<void> syncPending() async {
    if (await isConnected()) {
      try {
        final remote = await _api.getJson('/api/v1/purchase-orders');
        if (remote is List) {
          for (final raw in remote.whereType<Map>()) {
            final order = PurchaseOrder.fromJson(raw).copyWith(synced: true);
            await _ref.read(localDatabaseProvider).purchaseOrders.put(order);
          }
        }
      } catch (_) {
        // Continue with local retry queue when the server is unavailable.
      }
    }
    final orders = _ref.read(localDatabaseProvider).purchaseOrders.valuesForShop(_shopId);
    for (final order in orders.where((item) => !item.synced && !item.isDeleted)) {
      await _push(order);
    }
  }

  Future<void> _push(PurchaseOrder order) async {
    if (!await isConnected()) return;
    try {
      await _api.post('/api/v1/purchase-orders', order.toJson());
      await _ref.read(localDatabaseProvider).purchaseOrders.put(
            order.copyWith(synced: true, updatedAt: DateTime.now()),
          );
    } catch (_) {
      // The local unsynced order is retried when the planner opens again.
    }
  }
}

final purchasePlannerServiceProvider = Provider<PurchasePlannerService>((ref) {
  return PurchasePlannerService(ref);
});
