import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/models/purchase.dart';
import '../../../core/models/syncable.dart';
import '../../../features/products/providers/product_providers.dart';

final purchasesProvider = StreamProvider<List<Purchase>>((ref) {
  final shopId = ref.watch(shopIdProvider);
  return ref.watch(localDatabaseProvider).purchases.watchForShop(shopId);
});

final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  return PurchaseService(ref, const Uuid());
});

class PurchaseService {
  PurchaseService(this._ref, this._uuid);

  final Ref _ref;
  final Uuid _uuid;

  Future<void> addPurchase({
    required String supplierId,
    required List<PurchaseItem> items,
    required double paidAmount,
  }) async {
    final db = _ref.read(localDatabaseProvider);
    final shopId = _ref.read(shopIdProvider);

    final supplier = db.suppliers.getForShop(shopId, supplierId);
    if (supplier == null || supplier.isDeleted) {
      throw StateError('Supplier not found for this shop.');
    }
    if (items.isEmpty) {
      throw StateError('Purchase must contain at least one item.');
    }
    for (final item in items) {
      if (item.qty <= 0) {
        throw StateError('Quantity must be greater than zero.');
      }
      if (db.products.getForShop(shopId, item.productId) == null) {
        throw StateError('Product "${item.name}" not found.');
      }
    }

    final now = DateTime.now();
    final purchaseId = _uuid.v4();
    final total = items.fold<double>(0, (sum, item) => sum + item.lineTotal);
    await db.purchases.put(
      Purchase(
        purchaseId: purchaseId,
        supplierId: supplierId,
        items: items,
        totalAmount: total,
        paidAmount: paidAmount,
        shopId: shopId,
        createdAt: now,
        updatedAt: now,
        syncStatus: SyncStatus.pending,
      ),
    );

    final productService = _ref.read(productServiceProvider);
    final applied = <String, int>{};
    try {
      for (final item in items) {
        await productService.adjustStock(
          item.productId,
          item.qty.round(),
          syncAfterSave: false,
        );
        applied[item.productId] =
            (applied[item.productId] ?? 0) + item.qty.round();
      }
    } catch (error) {
      // Roll back stock increments already applied so a partial failure
      // never leaves the purchase recorded with mismatched stock levels.
      for (final entry in applied.entries) {
        try {
          await productService.adjustStock(
            entry.key,
            -entry.value,
            syncAfterSave: false,
          );
        } catch (_) {
          // best-effort rollback; original error takes precedence
        }
      }
      await db.purchases.remove(shopId, purchaseId);
      rethrow;
    }
    await _ref.read(syncStateProvider.notifier).syncIfOnline();
  }
}
