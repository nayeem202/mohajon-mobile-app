import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/sale.dart';
import '../../../core/models/syncable.dart';
import '../../../core/models/product.dart';
import '../../../features/products/providers/product_providers.dart';

final cartProvider = StateNotifierProvider<CartController, CartState>((ref) {
  return CartController(ref);
});

class CartState {
  const CartState({
    this.items = const [],
    this.discount = 0,
    this.customerId = '',
    this.paidAmount = 0,
  });

  final List<SaleItem> items;
  final double discount;
  final String customerId;
  final double paidAmount;

  double get subtotal => items.fold<double>(0, (sum, item) => sum + item.lineTotal);
  double get total => (subtotal - discount).clamp(0, double.infinity);
  double get due => (total - paidAmount).clamp(0, double.infinity);

  CartState copyWith({
    List<SaleItem>? items,
    double? discount,
    String? customerId,
    double? paidAmount,
  }) {
    return CartState(
      items: items ?? this.items,
      discount: discount ?? this.discount,
      customerId: customerId ?? this.customerId,
      paidAmount: paidAmount ?? this.paidAmount,
    );
  }
}

class CartController extends StateNotifier<CartState> {
  CartController(this._ref) : super(const CartState());

  final Ref _ref;
  final _uuid = const Uuid();

  void addProduct(Product product) {
    final existingIndex = state.items.indexWhere((item) => item.productId == product.productId);
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
      productId: current.productId,
      name: current.name,
      qty: current.qty + 1,
      unitPrice: current.unitPrice,
      purchasePrice: current.purchasePrice,
    );
    state = state.copyWith(items: items);
  }

  void setQty(String productId, double qty) {
    if (qty <= 0) {
      state = state.copyWith(items: state.items.where((item) => item.productId != productId).toList());
      return;
    }
    state = state.copyWith(
      items: state.items
          .map(
            (item) => item.productId == productId
                ? SaleItem(
                    productId: item.productId,
                    name: item.name,
                    qty: qty,
                    unitPrice: item.unitPrice,
                    purchasePrice: item.purchasePrice,
                  )
                : item,
          )
          .toList(),
    );
  }

  void setDiscount(double discount) => state = state.copyWith(discount: discount);
  void setCustomer(String customerId) => state = state.copyWith(customerId: customerId);
  void setPaidAmount(double amount) => state = state.copyWith(paidAmount: amount);
  void clear() => state = const CartState();

  Future<Sale> checkout() async {
    if (state.items.isEmpty) {
      throw StateError('Cart is empty');
    }
    if (state.due > 0 && state.customerId.isEmpty) {
      throw StateError('Select a customer before saving a due sale.');
    }
    final now = DateTime.now();
    final sale = Sale(
      saleId: _uuid.v4(),
      customerId: state.customerId,
      items: state.items,
      discount: state.discount,
      totalAmount: state.total,
      paidAmount: state.paidAmount,
      dueAmount: state.due,
      paymentStatus: state.due == 0
          ? PaymentStatus.paid
          : state.paidAmount > 0
              ? PaymentStatus.partial
              : PaymentStatus.due,
      shopId: _ref.read(shopIdProvider),
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.pending,
    );

    final db = _ref.read(localDatabaseProvider);
    await db.sales.put(sale);
    for (final item in state.items) {
      await _ref.read(productServiceProvider).adjustStock(
            item.productId,
            -item.qty,
            syncAfterSave: false,
          );
    }
    if (state.paidAmount > 0 && state.customerId.isNotEmpty) {
      await db.payments.put(
        Payment(
          paymentId: _uuid.v4(),
          customerId: state.customerId,
          saleId: sale.saleId,
          amount: state.paidAmount,
          paymentMethod: PaymentMethod.cash,
          shopId: sale.shopId,
          createdAt: now,
          updatedAt: now,
          syncStatus: SyncStatus.pending,
        ),
      );
    }
    clear();
    await _ref.read(syncStateProvider.notifier).syncIfOnline();
    return sale;
  }
}
