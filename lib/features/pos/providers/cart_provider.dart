import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/sale.dart';
import '../../../core/models/syncable.dart';
import '../../../core/models/product.dart';
import '../../../core/utils/money.dart';
import '../../../core/services/audit_service.dart';
import '../../../features/products/providers/product_providers.dart';
import '../../notifications/models/notification_model.dart';
import '../../notifications/providers/notification_providers.dart';

final cartProvider = StateNotifierProvider<CartController, CartState>((ref) {
  return CartController(ref);
});

class CartState {
  const CartState({
    this.items = const [],
    this.discount = 0,
    this.customerId = '',
    this.paidAmount = 0,
    this.vatPercent = 5,
    this.paymentMethod = PaymentMethod.cash,
    this.loyaltyPointsRedeemed = 0,
  });

  final List<SaleItem> items;
  final double discount;
  final String customerId;
  final double paidAmount;
  final double vatPercent;
  final PaymentMethod paymentMethod;
  final int loyaltyPointsRedeemed;

  double get subtotal =>
      moneyRound2(items.fold<double>(0, (sum, item) => sum + item.lineTotal));
  double get vatAmount => moneyRound2(subtotal * (vatPercent / 100));
  double get total =>
      moneyRound2((subtotal + vatAmount - discount).clamp(0, double.infinity));
  double get due => moneyRound2((total - paidAmount).clamp(0, double.infinity));

  CartState copyWith({
    List<SaleItem>? items,
    double? discount,
    String? customerId,
    double? paidAmount,
    double? vatPercent,
    PaymentMethod? paymentMethod,
    int? loyaltyPointsRedeemed,
  }) {
    return CartState(
      items: items ?? this.items,
      discount: discount ?? this.discount,
      customerId: customerId ?? this.customerId,
      paidAmount: paidAmount ?? this.paidAmount,
      vatPercent: vatPercent ?? this.vatPercent,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      loyaltyPointsRedeemed:
          loyaltyPointsRedeemed ?? this.loyaltyPointsRedeemed,
    );
  }
}

class CartController extends StateNotifier<CartState> {
  CartController(this._ref) : super(const CartState());

  final Ref _ref;
  final _uuid = const Uuid();

  void addProduct(Product product) {
    final existingIndex = state.items.indexWhere(
      (item) => item.productId == product.productId,
    );
    if (existingIndex == -1) {
      state = state.copyWith(
        items: [
          ...state.items,
          SaleItem(
            productId: product.productId,
            name: product.nameEn,
            qty: 1,
            unitPrice: product.sellingPrice,
            purchasePrice: product.purchasePrice,
          ),
        ],
      );
      return;
    }
    final items = [...state.items];
    final current = items[existingIndex];
    items[existingIndex] = SaleItem(
      saleItemId: current.saleItemId,
      productId: current.productId,
      name: current.name,
      qty: current.qty + 1,
      unitPrice: current.unitPrice,
      purchasePrice: current.purchasePrice,
      batchAllocations: current.batchAllocations,
    );
    state = state.copyWith(items: items);
  }

  void setQty(String productId, double qty) {
    if (qty <= 0) {
      state = state.copyWith(
        items: state.items
            .where((item) => item.productId != productId)
            .toList(),
      );
      return;
    }
    state = state.copyWith(
      items: state.items
          .map(
            (item) => item.productId == productId
                ? SaleItem(
                    saleItemId: item.saleItemId,
                    productId: item.productId,
                    name: item.name,
                    qty: qty,
                    unitPrice: item.unitPrice,
                    purchasePrice: item.purchasePrice,
                    batchAllocations: item.batchAllocations,
                  )
                : item,
          )
          .toList(),
    );
  }

  void setDiscount(double discount) =>
      state = state.copyWith(discount: discount);
  void setCustomer(String customerId) =>
      state = state.copyWith(customerId: customerId);
  void setPaidAmount(double amount) =>
      state = state.copyWith(paidAmount: amount);
  void setVatPercent(double vatPercent) =>
      state = state.copyWith(vatPercent: vatPercent);
  void setPaymentMethod(PaymentMethod method) =>
      state = state.copyWith(paymentMethod: method);
  void setLoyaltyPointsRedeemed(int points) =>
      state = state.copyWith(loyaltyPointsRedeemed: points);
  void clear() => state = const CartState();

  Future<Sale> checkout() async {
    if (state.items.isEmpty) {
      throw StateError('Cart is empty');
    }
    if (state.due > 0 && state.customerId.isEmpty) {
      throw StateError('Select a customer before saving a due sale.');
    }
    final totalAmount = state.total;
    if (totalAmount <= 0) {
      throw StateError('Sale total must be greater than zero.');
    }
    final paidAmount = moneyRound2(
      state.paidAmount > totalAmount ? totalAmount : state.paidAmount,
    );
    final db = _ref.read(localDatabaseProvider);
    if (state.due > 0 && state.customerId.isNotEmpty) {
      final customer = db.customers.getForShop(
        _ref.read(shopIdProvider),
        state.customerId,
      );
      if (customer?.creditLimit case final limit? when limit > 0) {
        final salesDue = db.sales
            .valuesForShop(_ref.read(shopIdProvider))
            .where(
              (sale) => sale.customerId == state.customerId && !sale.isDeleted,
            )
            .fold<double>(0, (sum, sale) => sum + sale.dueAmount);
        final payments = db.payments
            .valuesForShop(_ref.read(shopIdProvider))
            .where(
              (payment) =>
                  payment.customerId == state.customerId && !payment.isDeleted,
            )
            .fold<double>(0, (sum, payment) => sum + payment.amount);
        final currentDue = (salesDue - payments)
            .clamp(0, double.infinity)
            .toDouble();
        if (currentDue + state.due > limit) {
          throw StateError(
            'Customer credit limit exceeded. Available credit: ৳${(limit - currentDue).clamp(0, double.infinity).toStringAsFixed(2)}',
          );
        }
      }
    }
    for (final item in state.items) {
      final product = _ref.read(productServiceProvider).getActiveBranchProduct(item.productId);
      if (product == null) {
        throw StateError('${item.name} is no longer available.');
      }
      if (product.expiryDate case final expiry?
          when DateTime(expiry.year, expiry.month, expiry.day).isBefore(
            DateTime(
              DateTime.now().year,
              DateTime.now().month,
              DateTime.now().day,
            ),
          )) {
        throw StateError('${item.name} has expired and cannot be sold.');
      }
      if (product.stockQty < item.qty.round()) {
        throw StateError(
          '${item.name} has only ${product.stockQty} ${product.unit} in stock.',
        );
      }
    }
    final now = DateTime.now();
    final saleId = _uuid.v4();
    final invoiceNumber =
        'INV-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${saleId.substring(0, 6).toUpperCase()}';
    final saleItems = [...state.items];
    final sale = Sale(
      saleId: saleId,
      invoiceNumber: invoiceNumber,
      customerId: state.customerId,
      items: saleItems,
      discount: state.discount,
      vatPercent: state.vatPercent,
      charge: 0,
      totalAmount: totalAmount,
      paidAmount: paidAmount,
      dueAmount: moneyRound2(
        (totalAmount - paidAmount).clamp(0, double.infinity),
      ),
      paymentStatus: totalAmount - paidAmount == 0
          ? PaymentStatus.paid
          : paidAmount > 0
          ? PaymentStatus.partial
          : PaymentStatus.due,
      paymentMethod: state.paymentMethod,
      staffId: _ref.read(currentUserProvider)?.userId,
      branchId:
          db.settings.get('activeBranchId') as String? ??
          '${_ref.read(shopIdProvider)}-main',
      discountStaffId: state.discount > 0
          ? _ref.read(currentUserProvider)?.userId
          : null,
      loyaltyPointsRedeemed: state.loyaltyPointsRedeemed,
      loyaltyPointsEarned: (paidAmount / 100).floor(),
      shopId: _ref.read(shopIdProvider),
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.pending,
    );

    final shopId = sale.shopId;
    final customerBeforeSale = sale.customerId.isEmpty
        ? null
        : db.customers.getForShop(shopId, sale.customerId);
    // Overshoot-safe compensation (#7): each step is applied independently so
    // a failure in one write cannot silently inflate stock (by re-adding what
    // was never deducted) or delete an already-recorded sale.
    final adjustedQuantities = <String, int>{};
    final consumedBatches = <ProductBatchConsumption>[];
    Object? firstError;
    try {
      await db.sales.put(sale);
    } catch (error) {
      rethrow;
    }
    for (var index = 0; index < state.items.length; index++) {
      final item = state.items[index];
      try {
        await _ref
            .read(productServiceProvider)
            .adjustStock(
              item.productId,
              -item.qty.round(),
              syncAfterSave: false,
            );
        adjustedQuantities.update(
          item.productId,
          (value) => value + item.qty.round(),
          ifAbsent: () => item.qty.round(),
        );
        final consumed = await _ref
            .read(productServiceProvider)
            .consumeBatches(item.productId, item.qty.round());
        consumedBatches.addAll(consumed);
        saleItems[index] = SaleItem(
          saleItemId: item.saleItemId.isEmpty ? _uuid.v4() : item.saleItemId,
          productId: item.productId,
          name: item.name,
          qty: item.qty,
          unitPrice: item.unitPrice,
          purchasePrice: item.purchasePrice,
          batchAllocations: consumed
              .map(
                (allocation) => SaleBatchAllocation(
                  batchId: allocation.batchId,
                  quantity: allocation.quantity,
                ),
              )
              .toList(),
        );
      } catch (error) {
        firstError ??= error;
      }
    }
    if (firstError == null) {
      try {
        await db.sales.put(sale.copyWith(items: saleItems));
      } catch (error) {
        firstError = error;
      }
    }
    if (firstError == null && paidAmount > 0 && state.customerId.isNotEmpty) {
      try {
        await db.payments.put(
          Payment(
            paymentId: _uuid.v4(),
            customerId: state.customerId,
            saleId: sale.saleId,
            staffId: _ref.read(currentUserProvider)?.userId,
            branchId:
                db.settings.get('activeBranchId') as String? ??
                '${_ref.read(shopIdProvider)}-main',
            amount: paidAmount,
            paymentMethod: state.paymentMethod,
            shopId: shopId,
            createdAt: now,
            updatedAt: now,
            syncStatus: SyncStatus.pending,
          ),
        );
      } catch (error) {
        firstError ??= error;
      }
    }
    if (firstError == null && customerBeforeSale != null) {
      try {
        await db.customers.put(
          customerBeforeSale.copyWith(
            totalSpent: moneyRound2(customerBeforeSale.totalSpent + totalAmount),
            loyaltyPoints: (customerBeforeSale.loyaltyPoints -
                    sale.loyaltyPointsRedeemed + sale.loyaltyPointsEarned)
                .clamp(0, 1 << 30),
            updatedAt: now,
            syncStatus: SyncStatus.pending,
          ),
        );
      } catch (error) {
        firstError ??= error;
      }
    }
    if (firstError != null) {
      // The sale has not reached the server and no payment row is committed;
      // remove the local draft so a failed checkout cannot become an orphaned
      // sale during a later sync.
      for (final entry in adjustedQuantities.entries) {
        try {
          await _ref
              .read(productServiceProvider)
              .adjustStock(entry.key, entry.value, syncAfterSave: false);
        } catch (_) {}
      }
      try {
        await _ref
            .read(productServiceProvider)
            .restoreConsumedBatches(consumedBatches);
      } catch (_) {
        // Keep the original checkout error. A later sync/reconciliation can
        // surface a missing batch, but never hide the failed sale operation.
      }
      await db.sales.remove(shopId, sale.saleId);
      if (customerBeforeSale != null) {
        await db.customers.put(customerBeforeSale);
      }
      throw firstError;
    }
    if (sale.dueAmount > 0) {
      final message =
          '${sale.items.first.name} and more — ৳${sale.dueAmount.toStringAsFixed(2)} due from ${sale.customerId.isEmpty ? 'walk-in' : 'customer'}';
      unawaited(() async {
        try {
          await _ref
              .read(notificationServiceProvider)
              .sendPush(
                type: NotificationType.due,
                title: 'Due payment reminder',
                message: message,
              );
        } catch (_) {}
      }());
    }
    _ref
        .read(notificationServiceProvider)
        .add(
          type: NotificationType.sale,
          title: 'Sale completed',
          message: 'Sale of ৳${totalAmount.toStringAsFixed(2)} recorded.',
          sourceKey: 'sale:${sale.saleId}',
        );
    unawaited(
      _ref
          .read(auditServiceProvider)
          .record(
            action: 'SALE_CREATED',
            entityType: 'sale',
            entityId: sale.saleId,
            details: {
              'totalAmount': sale.totalAmount,
              'paidAmount': sale.paidAmount,
              'paymentMethod': sale.paymentMethod.value,
              'customerId': sale.customerId,
            },
          ),
    );
    clear();
    // Fire-and-forget: never hold the "success" screen hostage to a full
    // sync round-trip. The dashboard sync badge reflects the real state, and
    // auto-sync fires again on reconnect.
    unawaited(_ref.read(syncStateProvider.notifier).syncIfOnline());
    return sale;
  }
}
