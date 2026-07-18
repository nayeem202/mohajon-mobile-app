import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/models/product.dart';
import '../../../core/models/syncable.dart';

final productsProvider = StreamProvider<List<Product>>((ref) {
  final shopId = ref.watch(shopIdProvider);
  return ref.watch(localDatabaseProvider).products.watchForShop(shopId);
});

final productSearchQueryProvider = StateProvider.autoDispose<String>(
  (ref) => '',
);

final filteredProductsProvider = Provider<List<Product>>((ref) {
  final products = ref.watch(productsProvider).value ?? const <Product>[];
  final query = ref.watch(productSearchQueryProvider).trim().toLowerCase();
  if (query.isEmpty) return products;

  return products.where((product) {
    final searchFields = [
      product.nameEn,
      product.nameBn,
      product.barcode,
      product.category,
    ];
    return searchFields.any((field) => field.toLowerCase().contains(query));
  }).toList();
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
    double buyingPrice = 0,
    required double purchasePrice,
    required double sellingPrice,
    required int stockQty,
    required int lowStockAlert,
    String unit = 'pcs',
    String? imagePath,
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
        unit: unit,
        imagePath: imagePath,
        buyingPrice: buyingPrice,
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
    int delta, {
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
      product.copyWith(
        isDeleted: true,
        updatedAt: DateTime.now(),
        syncStatus: SyncStatus.pending,
      ),
    );
    await _ref.read(syncStateProvider.notifier).syncIfOnline();
  }
}
