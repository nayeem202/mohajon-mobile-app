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
    final now = DateTime.now();
    final total = items.fold<double>(0, (sum, item) => sum + item.lineTotal);
    await _ref.read(localDatabaseProvider).purchases.put(
          Purchase(
            purchaseId: _uuid.v4(),
            supplierId: supplierId,
            items: items,
            totalAmount: total,
            paidAmount: paidAmount,
            shopId: _ref.read(shopIdProvider),
            createdAt: now,
            updatedAt: now,
            syncStatus: SyncStatus.pending,
          ),
        );
    for (final item in items) {
      await _ref.read(productServiceProvider).adjustStock(
            item.productId,
            item.qty,
            syncAfterSave: false,
          );
    }
    await _ref.read(syncStateProvider.notifier).syncIfOnline();
  }
}
