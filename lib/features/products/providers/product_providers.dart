import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/models/product.dart';
import '../../../core/models/syncable.dart';

final productsProvider = StreamProvider<List<Product>>((ref) {
  final shopId = ref.watch(shopIdProvider);
  return ref.watch(localDatabaseProvider).products.watchForShop(shopId);
});

final productServiceProvider = Provider<ProductService>((ref) {
  return ProductService(ref, const Uuid());
});

class ProductService {
  ProductService(this._ref, this._uuid);

  final Ref _ref;
  final Uuid _uuid;

  Future<void> save({
    String? productId,
    required String nameEn,
    required String nameBn,
    required String barcode,
    required String category,
    required double purchasePrice,
    required double sellingPrice,
    required double stockQty,
    required double lowStockAlert,
  }) async {
    final db = _ref.read(localDatabaseProvider);
    final id = productId ?? _uuid.v4();
    await db.products.put(
      Product(
        productId: id,
        nameEn: nameEn,
        nameBn: nameBn,
        barcode: barcode,
        category: category,
        purchasePrice: purchasePrice,
        sellingPrice: sellingPrice,
        stockQty: stockQty,
        lowStockAlert: lowStockAlert,
        shopId: _ref.read(shopIdProvider),
        updatedAt: DateTime.now(),
        syncStatus: SyncStatus.pending,
      ),
    );
    await _ref.read(syncStateProvider.notifier).syncIfOnline();
  }

  Future<void> adjustStock(
    String productId,
    double delta, {
    bool syncAfterSave = true,
  }) async {
    final db = _ref.read(localDatabaseProvider);
    final shopId = _ref.read(shopIdProvider);
    final product = db.products.getForShop(shopId, productId);
    if (product == null) return;
    await db.products.put(
      product.copyWith(
        stockQty: product.stockQty + delta,
        updatedAt: DateTime.now(),
        syncStatus: SyncStatus.pending,
      ),
    );
    if (syncAfterSave) {
      await _ref.read(syncStateProvider.notifier).syncIfOnline();
    }
  }

  Future<void> delete(String productId) async {
    final db = _ref.read(localDatabaseProvider);
    final shopId = _ref.read(shopIdProvider);
    final product = db.products.getForShop(shopId, productId);
    if (product == null) return;
    await db.products.put(
      product.copyWith(isDeleted: true, updatedAt: DateTime.now(), syncStatus: SyncStatus.pending),
    );
    await _ref.read(syncStateProvider.notifier).syncIfOnline();
  }
}
