import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/models/product.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/syncable.dart';
import '../../../core/models/stock_adjustment.dart';
import '../../../core/models/product_batch.dart';
import '../../../core/services/file_upload_service.dart';
import '../../../core/services/audit_service.dart';
import '../../../core/offline/local_database.dart';
import '../../notifications/models/notification_model.dart';
import '../../notifications/providers/notification_providers.dart';
import '../../branches/providers/branch_providers.dart';

final productsProvider = StreamProvider<List<Product>>((ref) {
  final shopId = ref.watch(shopIdProvider);
  final branchId = ref.watch(currentBranchIdProvider) ?? '$shopId-main';
  return ref.watch(localDatabaseProvider).products.watchForShop(shopId).map(
        (items) => items.where((item) => (item.branchId ?? '$shopId-main') == branchId).toList(),
      );
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
      product.sku,
      product.variantName,
      product.batchNumber,
      product.category,
    ];
    return searchFields.any((field) => field.toLowerCase().contains(query));
  }).toList();
});

final productServiceProvider = Provider<ProductService>((ref) {
  return ProductService(ref, const Uuid());
});

class ProductBatchConsumption {
  const ProductBatchConsumption({required this.batchId, required this.quantity});

  final String batchId;
  final int quantity;
}

class ProductService {
  ProductService(this._ref, this._uuid);

  final Ref _ref;
  final Uuid _uuid;

  String _activeBranchId(LocalDatabase db, String shopId) =>
      db.settings.get('activeBranchId') as String? ?? '$shopId-main';

  Product? getActiveBranchProduct(String productId) {
    final db = _ref.read(localDatabaseProvider);
    final shopId = _ref.read(shopIdProvider);
    final branchId = _activeBranchId(db, shopId);
    return db.products.valuesForShop(shopId).where((p) =>
        p.productId == productId && (p.branchId ?? '$shopId-main') == branchId).firstOrNull;
  }

  Future<void> receiveBatch({
    required String productId,
    required int quantity,
    required double unitCost,
    required String batchNumber,
    DateTime? expiryDate,
  }) async {
    if (quantity <= 0 || batchNumber.trim().isEmpty) return;
    final db = _ref.read(localDatabaseProvider);
    final shopId = _ref.read(shopIdProvider);
    final branchId = db.settings.get('activeBranchId') as String? ?? '$shopId-main';
    final existing = db.productBatches.valuesForShop(shopId, includeDeleted: true)
        .where((batch) => !batch.isDeleted && batch.productId == productId &&
            batch.branchId == branchId &&
            batch.batchNumber == batchNumber.trim() && batch.expiryDate == expiryDate)
        .firstOrNull;
    final now = DateTime.now();
    final batch = existing == null
        ? ProductBatch(
            batchId: _uuid.v4(),
            productId: productId,
            batchNumber: batchNumber.trim(),
            expiryDate: expiryDate,
            quantity: quantity,
            unitCost: unitCost,
            shopId: shopId,
            branchId: branchId,
            updatedAt: now,
          )
        : existing.copyWith(quantity: existing.quantity + quantity, updatedAt: now);
    await db.productBatches.put(batch);
  }

  Future<List<ProductBatchConsumption>> consumeBatches(
    String productId,
    int quantity,
  ) async {
    if (quantity <= 0) return const [];
    final db = _ref.read(localDatabaseProvider);
    final shopId = _ref.read(shopIdProvider);
    final branchId = db.settings.get('activeBranchId') as String? ?? '$shopId-main';
    final today = DateTime.now();
    final batches = db.productBatches.valuesForShop(shopId)
        .where((batch) => batch.productId == productId && batch.branchId == branchId && batch.quantity > 0 &&
            (batch.expiryDate == null || !DateTime(batch.expiryDate!.year, batch.expiryDate!.month, batch.expiryDate!.day).isBefore(
              DateTime(today.year, today.month, today.day),
            )))
        .toList()
      ..sort((a, b) {
        if (a.expiryDate == null && b.expiryDate == null) return 0;
        if (a.expiryDate == null) return 1;
        if (b.expiryDate == null) return -1;
        return a.expiryDate!.compareTo(b.expiryDate!);
      });
    if (batches.isEmpty) return const []; // legacy stock has no batch ledger yet.
    final available = batches.fold<int>(0, (sum, batch) => sum + batch.quantity);
    if (available < quantity) {
      throw StateError('Batch stock is lower than product stock. Sync inventory before selling.');
    }
    var remaining = quantity;
    final consumed = <ProductBatchConsumption>[];
    for (final batch in batches) {
      if (remaining <= 0) break;
      final take = remaining > batch.quantity ? batch.quantity : remaining;
      await db.productBatches.put(batch.copyWith(
        quantity: batch.quantity - take,
        updatedAt: DateTime.now(),
      ));
      consumed.add(ProductBatchConsumption(batchId: batch.batchId, quantity: take));
      remaining -= take;
    }
    return consumed;
  }

  Future<void> restoreConsumedBatches(
    List<ProductBatchConsumption> consumed,
  ) async {
    if (consumed.isEmpty) return;
    final db = _ref.read(localDatabaseProvider);
    final shopId = _ref.read(shopIdProvider);
    for (final allocation in consumed) {
      final batch = db.productBatches.getForShop(shopId, allocation.batchId);
      if (batch == null || batch.isDeleted) {
        throw StateError('Consumed batch ${allocation.batchId} is missing during rollback.');
      }
      await db.productBatches.put(batch.copyWith(
        quantity: batch.quantity + allocation.quantity,
        updatedAt: DateTime.now(),
      ));
    }
  }

  Future<void> reverseReceivedBatch({
    required String productId,
    required int quantity,
    required String batchNumber,
    DateTime? expiryDate,
  }) async {
    if (quantity <= 0 || batchNumber.trim().isEmpty) return;
    final db = _ref.read(localDatabaseProvider);
    final shopId = _ref.read(shopIdProvider);
    final branchId = db.settings.get('activeBranchId') as String? ?? '$shopId-main';
    final batch = db.productBatches.valuesForShop(shopId, includeDeleted: true)
        .where((item) => !item.isDeleted && item.productId == productId &&
            item.branchId == branchId &&
            item.batchNumber == batchNumber.trim() && item.expiryDate == expiryDate)
        .firstOrNull;
    if (batch == null) return;
    final remaining = batch.quantity - quantity;
    if (remaining < 0) throw StateError('Batch rollback would make quantity negative.');
    await db.productBatches.put(batch.copyWith(quantity: remaining, updatedAt: DateTime.now()));
  }

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
    DateTime? expiryDate,
    String batchNumber = '',
    String sku = '',
    String variantName = '',
    String unit = 'pcs',
    String? imagePath,
  }) async {
    final db = _ref.read(localDatabaseProvider);
    final id = productId ?? _uuid.v4();
    // Upload immediately when possible; when offline, keep the local file
    // path so the product still saves. The sync layer uploads the photo on
    // the next online sync and swaps in the server URL.
    var resolvedImagePath = imagePath;
    if (imagePath != null && imagePath.isNotEmpty && !imagePath.startsWith('http')) {
      try {
        resolvedImagePath = await FileUploadService(db).uploadIfNeeded(imagePath);
      } catch (_) {
        resolvedImagePath = imagePath;
      }
    }
    await db.products.put(
      Product(
        productId: id,
        nameEn: nameEn,
        nameBn: nameBn,
        barcode: barcode,
        category: category,
        unit: unit,
        imagePath: resolvedImagePath,
        buyingPrice: buyingPrice,
        purchasePrice: purchasePrice,
        sellingPrice: sellingPrice,
        stockQty: stockQty,
        lowStockAlert: lowStockAlert,
        expiryDate: expiryDate,
        batchNumber: batchNumber,
        sku: sku,
        variantName: variantName,
        shopId: _ref.read(shopIdProvider),
        branchId: _activeBranchId(db, _ref.read(shopIdProvider)),
        updatedAt: DateTime.now(),
        syncStatus: SyncStatus.pending,
      ),
    );
    unawaited(_ref.read(syncStateProvider.notifier).syncIfOnline());
  }

  Future<void> adjustStock(
    String productId,
    int delta, {
    bool syncAfterSave = true,
  }) async {
    final db = _ref.read(localDatabaseProvider);
    final product = getActiveBranchProduct(productId);
    if (product == null) return;
    if (product.stockQty + delta < 0) {
      throw StateError('${product.nameEn} stock cannot become negative.');
    }
    final updated = product.copyWith(
        stockQty: product.stockQty + delta,
        updatedAt: DateTime.now(),
        syncStatus: SyncStatus.pending,
      );
    await db.products.put(updated);
    if (updated.isLowStock) {
      final day = DateTime.now();
      final message = '${updated.nameEn} has ${updated.stockQty} ${updated.unit} left.';
      _ref.read(notificationServiceProvider).add(
            type: NotificationType.stock,
            title: 'Low stock alert',
            message: message,
            sourceKey: 'low-stock:${updated.productId}:${day.year}-${day.month}-${day.day}',
          );
      // Best-effort remote push so the owner's other devices learn about the
      // low stock even when no staff account is watching this device.
      unawaited(() async {
        try {
          await _ref.read(notificationServiceProvider).sendPush(
                type: NotificationType.stock,
                title: 'Low stock alert',
                message: message,
              );
        } catch (_) {}
      }());
    }
    if (syncAfterSave) {
      unawaited(_ref.read(syncStateProvider.notifier).syncIfOnline());
    }
  }

  Future<void> delete(String productId) async {
    final db = _ref.read(localDatabaseProvider);
    final product = getActiveBranchProduct(productId);
    if (product == null) return;
    await db.products.put(
      product.copyWith(
        isDeleted: true,
        updatedAt: DateTime.now(),
        syncStatus: SyncStatus.pending,
      ),
    );
    unawaited(_ref.read(syncStateProvider.notifier).syncIfOnline());
  }

  Future<StockAdjustment> requestStockAdjustment({
    required String productId,
    required int delta,
    required String reason,
  }) async {
    if (delta == 0) throw StateError('Adjustment quantity cannot be zero.');
    if (reason.trim().length < 3) throw StateError('Enter a reason for this adjustment.');
    final db = _ref.read(localDatabaseProvider);
    final shopId = _ref.read(shopIdProvider);
    final product = getActiveBranchProduct(productId);
    if (product == null || product.isDeleted) throw StateError('Product not found.');
    if (product.stockQty + delta < 0) throw StateError('Stock cannot become negative.');
    final actor = _ref.read(currentUserProvider);
    final now = DateTime.now();
    final approved = actor?.role == UserRole.owner;
    var adjustment = StockAdjustment(
      adjustmentId: _uuid.v4(),
      productId: productId,
      delta: delta,
      reason: reason.trim(),
      actorId: actor?.userId ?? 'unknown',
      shopId: shopId,
      branchId: db.settings.get('activeBranchId') as String? ?? '$shopId-main',
      status: approved
          ? StockAdjustmentStatus.approved
          : StockAdjustmentStatus.pendingApproval,
      createdAt: now,
      updatedAt: now,
      approverId: approved ? actor?.userId : null,
    );
    await db.stockAdjustments.put(adjustment);
    await _ref.read(auditServiceProvider).record(
          action: approved ? 'STOCK_ADJUSTMENT_APPROVED' : 'STOCK_ADJUSTMENT_REQUESTED',
          entityType: 'stock_adjustment',
          entityId: adjustment.adjustmentId,
          details: {'productId': productId, 'delta': delta, 'reason': reason.trim()},
        );
    if (approved) {
      await adjustStock(productId, delta, syncAfterSave: false);
      adjustment = adjustment.copyWith(updatedAt: DateTime.now());
      await db.stockAdjustments.put(adjustment);
    }
    unawaited(_ref.read(syncStateProvider.notifier).syncIfOnline());
    return adjustment;
  }

  Future<void> approveStockAdjustment(String adjustmentId) async {
    final actor = _ref.read(currentUserProvider);
    if (actor?.role != UserRole.owner) throw StateError('Only the owner can approve stock changes.');
    final db = _ref.read(localDatabaseProvider);
    final shopId = _ref.read(shopIdProvider);
    final adjustment = db.stockAdjustments.getForShop(shopId, adjustmentId);
    if (adjustment == null || adjustment.isDeleted) throw StateError('Adjustment not found.');
    if (adjustment.status != StockAdjustmentStatus.pendingApproval) return;
    await adjustStock(adjustment.productId, adjustment.delta, syncAfterSave: false);
    await db.stockAdjustments.put(adjustment.copyWith(
      status: StockAdjustmentStatus.approved,
      approverId: actor!.userId,
      updatedAt: DateTime.now(),
    ));
    await _ref.read(auditServiceProvider).record(
          action: 'STOCK_ADJUSTMENT_APPROVED',
          entityType: 'stock_adjustment',
          entityId: adjustment.adjustmentId,
          details: {'productId': adjustment.productId, 'delta': adjustment.delta},
        );
    unawaited(_ref.read(syncStateProvider.notifier).syncIfOnline());
  }

  Future<void> rejectStockAdjustment(String adjustmentId) async {
    final actor = _ref.read(currentUserProvider);
    if (actor?.role != UserRole.owner) throw StateError('Only the owner can reject stock changes.');
    final db = _ref.read(localDatabaseProvider);
    final shopId = _ref.read(shopIdProvider);
    final adjustment = db.stockAdjustments.getForShop(shopId, adjustmentId);
    if (adjustment == null || adjustment.isDeleted) throw StateError('Adjustment not found.');
    if (adjustment.status != StockAdjustmentStatus.pendingApproval) return;
    await db.stockAdjustments.put(adjustment.copyWith(
      status: StockAdjustmentStatus.rejected,
      approverId: actor!.userId,
      updatedAt: DateTime.now(),
    ));
    await _ref.read(auditServiceProvider).record(
          action: 'STOCK_ADJUSTMENT_REJECTED',
          entityType: 'stock_adjustment',
          entityId: adjustment.adjustmentId,
          details: {'productId': adjustment.productId, 'delta': adjustment.delta},
        );
    unawaited(_ref.read(syncStateProvider.notifier).syncIfOnline());
  }
}
