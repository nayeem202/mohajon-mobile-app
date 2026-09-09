import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/sale.dart';
import '../../../core/models/syncable.dart';
import '../../../core/models/product.dart';
import '../../../core/utils/money.dart';
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
  });

  final List<SaleItem> items;
  final double discount;
  final String customerId;
  final double paidAmount;
  final double vatPercent;
  final PaymentMethod paymentMethod;

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
  }) {
    return CartState(
      items: items ?? this.items,
      discount: discount ?? this.discount,
      customerId: customerId ?? this.customerId,
      paidAmount: paidAmount ?? this.paidAmount,
      vatPercent: vatPercent ?? this.vatPercent,
      paymentMethod: paymentMethod ?? this.paymentMethod,
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
  void setVatPercent(double vatPercent) => state = state.copyWith(vatPercent: vatPercent);
  void setPaymentMethod(PaymentMethod method) => state = state.copyWith(paymentMethod: method);
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
    for (final item in state.items) {
      final product = db.products.getForShop(_ref.read(shopIdProvider), item.productId);
      if (product == null) throw StateError('${item.name} is no longer available.');
      if (product.stockQty < item.qty.round()) {
        throw StateError('${item.name} has only ${product.stockQty} ${product.unit} in stock.');
      }
    }
    final now = DateTime.now();
    final sale = Sale(
      saleId: _uuid.v4(),
      customerId: state.customerId,
      items: state.items,
      discount: state.discount,
      vatPercent: state.vatPercent,
      charge: 0,
      totalAmount: totalAmount,
      paidAmount: paidAmount,
      dueAmount: moneyRound2((totalAmount - paidAmount).clamp(0, double.infinity)),
      paymentStatus: totalAmount - paidAmount == 0
          ? PaymentStatus.paid
          : paidAmount > 0
              ? PaymentStatus.partial
              : PaymentStatus.due,
      shopId: _ref.read(shopIdProvider),
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.pending,
    );

    final shopId = sale.shopId;
    try {
      await db.sales.put(sale);
      for (final item in state.items) {
        await _ref.read(productServiceProvider).adjustStock(
              item.productId,
              -item.qty.round(),
              syncAfterSave: false,
            );
      }
      if (paidAmount > 0 && state.customerId.isNotEmpty) {
        await db.payments.put(
          Payment(
            paymentId: _uuid.v4(),
            customerId: state.customerId,
            saleId: sale.saleId,
            amount: paidAmount,
            paymentMethod: state.paymentMethod,
            shopId: shopId,
            createdAt: now,
            updatedAt: now,
            syncStatus: SyncStatus.pending,
          ),
        );
      }
    } catch (error) {
      // Compensate for partially applied writes so a user retry cannot
      // duplicate the sale, payment, or stock deduction.
      for (final item in state.items) {
        await _ref.read(productServiceProvider).adjustStock(
              item.productId,
              item.qty.round(),
              syncAfterSave: false,
            );
      }
      await db.sales.remove(shopId, sale.saleId);
      rethrow;
    }
    _ref.read(notificationServiceProvider).add(
          type: NotificationType.sale,
          title: 'Sale completed',
          message: 'Sale of ৳${totalAmount.toStringAsFixed(2)} recorded.',
          sourceKey: 'sale:${sale.saleId}',
        );
    clear();
    await _ref.read(syncStateProvider.notifier).syncIfOnline();
    return sale;
  }
}
