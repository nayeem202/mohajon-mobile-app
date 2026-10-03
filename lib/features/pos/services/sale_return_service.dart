import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/models/sale.dart';
import '../../../core/models/sale_return.dart';
import '../../../core/models/syncable.dart';
import '../../../core/services/audit_service.dart';
import '../../../core/utils/money.dart';
import '../../products/providers/product_providers.dart';

final saleReturnServiceProvider = Provider<SaleReturnService>((ref) {
  return SaleReturnService(ref, const Uuid());
});

final saleReturnsProvider = StreamProvider<List<SaleReturn>>((ref) {
  final shopId = ref.watch(shopIdProvider);
  return ref.watch(localDatabaseProvider).saleReturns.watchForShop(shopId);
});

class SaleReturnRequestItem {
  const SaleReturnRequestItem({required this.saleItemId, required this.qty});

  final String saleItemId;
  final int qty;
}

class SaleReturnService {
  SaleReturnService(this._ref, this._uuid);

  final Ref _ref;
  final Uuid _uuid;

  Future<SaleReturn> create({
    required Sale sale,
    required List<SaleReturnRequestItem> items,
    required String refundMethod,
    String reason = '',
  }) async {
    if (items.isEmpty) throw StateError('Select at least one item to return.');
    if (refundMethod.trim().isEmpty) {
      throw StateError('Refund method is required.');
    }
    final db = _ref.read(localDatabaseProvider);
    final shopId = _ref.read(shopIdProvider);
    final branchId =
        sale.branchId ??
        db.settings.get('activeBranchId') as String? ??
        '$shopId-main';
    final alreadyReturned = <String, double>{};
    for (final previous in db.saleReturns.valuesForShop(shopId)) {
      if (previous.saleId != sale.saleId || previous.branchId != branchId) {
        continue;
      }
      for (final item in previous.items) {
        alreadyReturned.update(
          item.saleItemId,
          (value) => value + item.qty,
          ifAbsent: () => item.qty,
        );
      }
    }
    final sourceById = <String, SaleItem>{
      for (final item in sale.items)
        if (item.saleItemId.isNotEmpty) item.saleItemId: item,
    };
    if (sourceById.length != sale.items.length) {
      throw StateError(
        'This older invoice cannot be returned offline. Sync it first.',
      );
    }
    final returnId = _uuid.v4();
    final returnItems = <SaleReturnItem>[];
    final stockChanges = <String, int>{};
    final restoredBatches = <ProductBatchConsumption>[];
    final customer = sale.customerId.isEmpty
        ? null
        : db.customers.getForShop(shopId, sale.customerId);
    var refund = 0.0;
    final subtotal = sale.items.fold<double>(
      0,
      (sum, item) => sum + item.lineTotal,
    );
    final netLineRatio = subtotal <= 0 ? 1.0 : sale.totalAmount / subtotal;
    try {
      for (final request in items) {
        if (request.qty <= 0) {
          throw StateError('Return quantity must be positive.');
        }
        final source = sourceById[request.saleItemId];
        if (source == null) {
          throw StateError('Selected item is not part of this invoice.');
        }
        final remaining =
            source.qty - (alreadyReturned[request.saleItemId] ?? 0);
        if (request.qty > remaining) {
          throw StateError('Return quantity exceeds remaining quantity.');
        }
        refund = moneyRound2(
          refund + request.qty * source.unitPrice * netLineRatio,
        );
        if (source.productId.isNotEmpty) {
          await _ref
              .read(productServiceProvider)
              .adjustStock(source.productId, request.qty, syncAfterSave: false);
          stockChanges.update(
            source.productId,
            (value) => value + request.qty,
            ifAbsent: () => request.qty,
          );
          var batchRemaining = request.qty;
          var allocationOffset = (alreadyReturned[request.saleItemId] ?? 0)
              .toInt();
          final allocations = <ProductBatchConsumption>[];
          for (final item in source.batchAllocations) {
            if (batchRemaining <= 0) break;
            if (allocationOffset >= item.quantity) {
              allocationOffset -= item.quantity;
              continue;
            }
            final available = item.quantity - allocationOffset;
            final take = batchRemaining < available
                ? batchRemaining
                : available;
            allocations.add(
              ProductBatchConsumption(batchId: item.batchId, quantity: take),
            );
            batchRemaining -= take;
            allocationOffset = 0;
          }
          await _ref
              .read(productServiceProvider)
              .restoreConsumedBatches(allocations);
          restoredBatches.addAll(allocations);
        }
        returnItems.add(
          SaleReturnItem(
            returnItemId: _uuid.v4(),
            saleItemId: request.saleItemId,
            productId: source.productId,
            name: source.name,
            qty: request.qty.toDouble(),
            unitPrice: source.unitPrice,
            purchasePrice: source.purchasePrice,
          ),
        );
      }
      final loyaltyRatio = sale.totalAmount <= 0
          ? 1.0
          : (refund / sale.totalAmount).clamp(0.0, 1.0);
      final now = DateTime.now();
      final value = SaleReturn(
        returnId: returnId,
        saleId: sale.saleId,
        customerId: sale.customerId,
        items: returnItems,
        refundAmount: refund,
        refundMethod: refundMethod.trim().toUpperCase(),
        reason: reason.trim(),
        staffId: _ref.read(currentUserProvider)?.userId,
        branchId: branchId,
        shopId: shopId,
        createdAt: now,
        updatedAt: now,
        syncStatus: SyncStatus.pending,
      );
      final newTotal = moneyRound2(
        (sale.totalAmount - refund).clamp(0, double.infinity),
      );
      final newPaid = moneyRound2(sale.paidAmount.clamp(0, newTotal));
      final newDue = moneyRound2(
        (newTotal - newPaid).clamp(0, double.infinity),
      );
      final adjustedSale = sale.copyWith(
        totalAmount: newTotal,
        paidAmount: newPaid,
        dueAmount: newDue,
        paymentStatus: newDue <= 0
            ? PaymentStatus.paid
            : newPaid > 0
            ? PaymentStatus.partial
            : PaymentStatus.due,
        updatedAt: now,
        syncStatus: SyncStatus.pending,
      );
      await db.sales.put(adjustedSale);
      if (customer != null) {
        final reversedEarned = (sale.loyaltyPointsEarned * loyaltyRatio).floor();
        final restoredRedeemed = (sale.loyaltyPointsRedeemed * loyaltyRatio).floor();
        await db.customers.put(
          customer.copyWith(
            totalSpent: moneyRound2(
              (customer.totalSpent - refund).clamp(0, double.infinity),
            ),
            loyaltyPoints: (customer.loyaltyPoints - reversedEarned + restoredRedeemed)
                .clamp(0, 1 << 30),
            updatedAt: now,
            syncStatus: SyncStatus.pending,
          ),
        );
      }
      await db.saleReturns.put(value);
      await _ref
          .read(auditServiceProvider)
          .record(
            action: 'SALE_RETURN_CREATED',
            entityType: 'sale_return',
            entityId: returnId,
            details: {'saleId': sale.saleId, 'refundAmount': refund},
          );
      return value;
    } catch (error) {
      for (final entry in stockChanges.entries) {
        try {
          await _ref
              .read(productServiceProvider)
              .adjustStock(entry.key, -entry.value, syncAfterSave: false);
        } catch (_) {}
      }
      try {
        await db.sales.put(sale);
      } catch (_) {}
      if (customer != null) {
        try {
          await db.customers.put(customer);
        } catch (_) {}
      }
      // The batch restore is exact for the allocations recorded on the sale;
      // undo it by decrementing the same allocations through the normal stock
      // path only when a persisted return was not created.
      for (final allocation in restoredBatches) {
        try {
          final dbBatch = db.productBatches.getForShop(
            shopId,
            allocation.batchId,
          );
          if (dbBatch != null && dbBatch.quantity >= allocation.quantity) {
            await db.productBatches.put(
              dbBatch.copyWith(
                quantity: dbBatch.quantity - allocation.quantity,
                updatedAt: DateTime.now(),
              ),
            );
          }
        } catch (_) {}
      }
      rethrow;
    }
  }
}
