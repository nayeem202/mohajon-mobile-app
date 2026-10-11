import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/models/purchase.dart';
import '../../../core/models/syncable.dart';
import '../models/supplier_return.dart';
import '../models/purchase_receipt.dart';
import '../../../features/products/providers/product_providers.dart';
import '../../../core/services/audit_service.dart';
import '../../branches/providers/branch_providers.dart';
import '../services/purchase_order_service.dart';

final purchasesProvider = StreamProvider<List<Purchase>>((ref) {
  final shopId = ref.watch(shopIdProvider);
  final branchId = ref.watch(currentBranchIdProvider) ?? '$shopId-main';
  return ref
      .watch(localDatabaseProvider)
      .purchases
      .watchForShop(shopId)
      .map(
        (items) => items
            .where((item) => (item.branchId ?? '$shopId-main') == branchId)
            .toList(),
      );
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
      if (_ref
              .read(productServiceProvider)
              .getActiveBranchProduct(item.productId) ==
          null) {
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
        branchId:
            db.settings.get('activeBranchId') as String? ?? '$shopId-main',
        staffId: db.settings.get('activeUserId') as String? ?? 'local-owner',
        createdAt: now,
        updatedAt: now,
        syncStatus: SyncStatus.pending,
      ),
    );

    final productService = _ref.read(productServiceProvider);
    final applied = <String, int>{};
    final receivedBatches = <PurchaseItem>[];
    try {
      for (final item in items) {
        await productService.adjustStock(
          item.productId,
          item.qty.round(),
          syncAfterSave: false,
        );
        applied[item.productId] =
            (applied[item.productId] ?? 0) + item.qty.round();
        await productService.receiveBatch(
          productId: item.productId,
          quantity: item.qty.round(),
          unitCost: item.unitCost,
          batchNumber: item.batchNumber,
          expiryDate: item.expiryDate,
        );
        receivedBatches.add(item);
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
      for (final item in receivedBatches) {
        try {
          await productService.reverseReceivedBatch(
            productId: item.productId,
            quantity: item.qty.round(),
            batchNumber: item.batchNumber,
            expiryDate: item.expiryDate,
          );
        } catch (_) {}
      }
      await db.purchases.remove(shopId, purchaseId);
      rethrow;
    }
    await _ref.read(syncStateProvider.notifier).syncIfOnline();
  }

  Future<void> receiveOrder({
    required String orderId,
    required Map<String, double> deliveredQuantities,
    required Map<String, double> damagedQuantities,
    required Map<String, double> actualUnitCosts,
    required double invoiceAmount,
    String invoiceNumber = '',
    double freightAmount = 0,
    double discountAmount = 0,
    String attachmentPath = '',
    String notes = '',
    Map<String, String> itemIssueNotes = const {},
  }) async {
    final db = _ref.read(localDatabaseProvider);
    final shopId = _ref.read(shopIdProvider);
    final branchId =
        db.settings.get('activeBranchId') as String? ?? '$shopId-main';
    final order = db.purchaseOrders
        .valuesForShop(shopId)
        .where(
          (item) =>
              item.orderId == orderId &&
              (item.branchId ?? '$shopId-main') == branchId,
        )
        .firstOrNull;
    if (order == null || order.isDeleted) {
      throw StateError('Purchase order not found.');
    }
    final received = Map<String, double>.from(order.receivedQty);
    final delivered = Map<String, double>.from(order.deliveredQty);
    final items = <PurchaseItem>[];
    final receiptItems = <PurchaseReceiptItem>[];
    for (final item in order.items) {
      final requested = deliveredQuantities[item.productId] ?? 0;
      final damaged = damagedQuantities[item.productId] ?? 0;
      final already =
          delivered[item.productId] ?? received[item.productId] ?? 0;
      final remaining = item.qty - already;
      final unitCost = actualUnitCosts[item.productId] ?? item.unitCost;
      if (!requested.isFinite ||
          !damaged.isFinite ||
          !unitCost.isFinite ||
          requested < 0 ||
          damaged < 0 ||
          damaged > requested ||
          requested > remaining ||
          unitCost < 0) {
        throw StateError(
          'Received quantity exceeds the remaining order quantity.',
        );
      }
      if (requested != requested.floorToDouble() ||
          damaged != damaged.floorToDouble()) {
        throw StateError('Supplier delivery quantities must be whole numbers.');
      }
      if (requested > 0) {
        final accepted = requested - damaged;
        final issueNote = itemIssueNotes[item.productId]?.trim() ?? '';
        if (damaged > 0 && issueNote.length < 3) {
          throw StateError(
            'A reason is required for damaged or rejected items.',
          );
        }
        if (accepted > 0) {
          items.add(
            PurchaseItem(
              productId: item.productId,
              name: item.name,
              qty: accepted,
              unitCost: unitCost,
              batchNumber: item.batchNumber,
              expiryDate: item.expiryDate,
            ),
          );
          received[item.productId] = (received[item.productId] ?? 0) + accepted;
        }
        delivered[item.productId] = already + requested;
        receiptItems.add(
          PurchaseReceiptItem(
            productId: item.productId,
            orderedQty: remaining,
            deliveredQty: requested,
            acceptedQty: accepted,
            damagedQty: damaged,
            unitCost: unitCost,
            orderedUnitCost: item.unitCost,
            issueNote: issueNote,
          ),
        );
      }
    }
    if (receiptItems.isEmpty) {
      throw StateError('Enter at least one received quantity.');
    }
    if (!invoiceAmount.isFinite ||
        invoiceAmount < 0 ||
        !freightAmount.isFinite ||
        freightAmount < 0 ||
        !discountAmount.isFinite ||
        discountAmount < 0) {
      throw StateError('Enter valid invoice, freight and discount amounts.');
    }
    if (discountAmount >
        receiptItems.fold<double>(
              0,
              (sum, item) => sum + item.acceptedQty * item.orderedUnitCost,
            ) +
            freightAmount) {
      throw StateError(
        'Discount cannot exceed the received goods and freight total.',
      );
    }
    final calculatedInvoice =
        receiptItems.fold<double>(
          0,
          (sum, item) => sum + item.acceptedQty * item.orderedUnitCost,
        ) +
        freightAmount -
        discountAmount;
    if ((invoiceAmount - calculatedInvoice).abs() > 0.01 &&
        notes.trim().isEmpty) {
      throw StateError(
        'Invoice total differs from the calculated amount. Add a note explaining the difference.',
      );
    }
    if (items.isNotEmpty) {
      final acceptedBaseCost = items.fold<double>(
        0,
        (sum, item) => sum + item.qty * item.unitCost,
      );
      final acceptedQty = items.fold<double>(0, (sum, item) => sum + item.qty);
      final landedCostItems = items.map((item) {
        final allocation = acceptedBaseCost > 0
            ? (item.qty * item.unitCost) / acceptedBaseCost
            : item.qty / acceptedQty;
        return PurchaseItem(
          productId: item.productId,
          name: item.name,
          qty: item.qty,
          unitCost: invoiceAmount * allocation / item.qty,
          batchNumber: item.batchNumber,
          expiryDate: item.expiryDate,
        );
      }).toList();
      await addPurchase(
        supplierId: order.supplierId,
        items: landedCostItems,
        paidAmount: 0,
      );
    }
    final receipt = PurchaseReceipt(
      receiptId: _uuid.v4(),
      receivedAt: DateTime.now(),
      items: receiptItems,
      invoiceNumber: invoiceNumber.trim(),
      invoiceAmount: invoiceAmount,
      freightAmount: freightAmount,
      discountAmount: discountAmount,
      attachmentPath: attachmentPath,
      notes: notes.trim(),
    );
    await _ref
        .read(auditServiceProvider)
        .record(
          action: 'PURCHASE_RECEIVED',
          entityType: 'purchase_order',
          entityId: orderId,
          details: {'receipt': receipt.toJson()},
        );
    final complete = order.items.every(
      (item) => (delivered[item.productId] ?? 0) >= item.qty,
    );
    await db.purchaseOrders.put(
      order.copyWith(
        receivedQty: received,
        deliveredQty: delivered,
        receipts: [...order.receipts, receipt],
        status: complete ? 'RECEIVED' : 'PARTIALLY_RECEIVED',
        updatedAt: DateTime.now(),
        synced: false,
        syncStatus: SyncStatus.pending,
      ),
    );
    await _ref.read(purchasePlannerServiceProvider).syncPending();
  }

  Future<SupplierReturn> returnFromOrder({
    required String orderId,
    required Map<String, double> quantities,
    required String reason,
  }) async {
    if (reason.trim().length < 3) {
      throw StateError('Enter a reason for the supplier return.');
    }
    final db = _ref.read(localDatabaseProvider);
    final shopId = _ref.read(shopIdProvider);
    final branchId =
        db.settings.get('activeBranchId') as String? ?? '$shopId-main';
    final order = db.purchaseOrders
        .valuesForShop(shopId)
        .where(
          (item) =>
              item.orderId == orderId &&
              (item.branchId ?? '$shopId-main') == branchId,
        )
        .firstOrNull;
    if (order == null || order.isDeleted) {
      throw StateError('Purchase order not found.');
    }
    final alreadyReturned = <String, double>{};
    for (final item
        in db.supplierReturns
            .valuesForShop(shopId)
            .where((item) => (item.branchId ?? '$shopId-main') == branchId)) {
      if (item.orderId != orderId || item.isDeleted) continue;
      for (final returned in item.items) {
        alreadyReturned[returned.productId] =
            (alreadyReturned[returned.productId] ?? 0) + returned.qty;
      }
    }
    final items = <SupplierReturnItem>[];
    for (final item in order.items) {
      final qty = quantities[item.productId] ?? 0;
      final received = order.receivedQty[item.productId] ?? 0;
      final available = received - (alreadyReturned[item.productId] ?? 0);
      if (!qty.isFinite ||
          qty < 0 ||
          qty != qty.floorToDouble() ||
          qty > available) {
        throw StateError('Return quantity exceeds received quantity.');
      }
      if (!item.unitCost.isFinite || item.unitCost < 0) {
        throw StateError('Supplier return unit cost is invalid.');
      }
      if (qty > 0) {
        items.add(
          SupplierReturnItem(
            productId: item.productId,
            name: item.name,
            qty: qty,
            unitCost: item.unitCost,
          ),
        );
      }
    }
    if (items.isEmpty) throw StateError('Enter at least one return quantity.');
    for (final item in items) {
      final product = _ref
          .read(productServiceProvider)
          .getActiveBranchProduct(item.productId);
      if (product == null || product.stockQty < item.qty.round()) {
        throw StateError('${item.name} does not have enough stock to return.');
      }
    }
    for (final item in items) {
      await _ref
          .read(productServiceProvider)
          .adjustStock(item.productId, -item.qty.round(), syncAfterSave: false);
    }
    final actor = _ref.read(currentUserProvider);
    final now = DateTime.now();
    final result = SupplierReturn(
      returnId: _uuid.v4(),
      orderId: orderId,
      supplierId: order.supplierId,
      items: items,
      totalAmount: items.fold<double>(
        0,
        (sum, item) => sum + item.qty * item.unitCost,
      ),
      reason: reason.trim(),
      actorId: actor?.userId ?? 'unknown',
      shopId: shopId,
      branchId: branchId,
      createdAt: now,
      updatedAt: now,
    );
    await db.supplierReturns.put(result);
    await _ref
        .read(auditServiceProvider)
        .record(
          action: 'SUPPLIER_RETURN_CREATED',
          entityType: 'supplier_return',
          entityId: result.returnId,
          details: {
            'orderId': orderId,
            'amount': result.totalAmount,
            'reason': reason.trim(),
          },
        );
    await _ref.read(syncStateProvider.notifier).syncIfOnline();
    return result;
  }
}
