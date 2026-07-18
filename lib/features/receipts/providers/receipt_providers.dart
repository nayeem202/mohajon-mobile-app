import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/product.dart';
import '../../../core/models/sale.dart';
import '../../../core/models/syncable.dart';
import '../../products/providers/product_providers.dart';
import '../models/receipt.dart';

final receiptViewModelProvider =
    StateNotifierProvider.autoDispose<ReceiptViewModel, Receipt>((ref) {
      return ReceiptViewModel(const Uuid());
    });

class ReceiptViewModel extends StateNotifier<Receipt> {
  ReceiptViewModel(this._uuid) : super(_initialReceipt());

  final Uuid _uuid;

  static Receipt _initialReceipt() {
    final now = DateTime.now();
    return Receipt(
      companyName: '',
      companyAddress: '',
      companyPhone: '',
      customerId: '',
      customerName: '',
      customerPhone: '',
      receiptNumber: 'RCP-${now.millisecondsSinceEpoch}',
      paymentMethod: receiptPaymentMethods.first, // Cash
      items: [
        ReceiptItem(
          id: const Uuid().v4(),
          productId: '',
          description: '',
          quantity: 1,
          price: 0,
          purchasePrice: 0,
        ),
      ],
      discountType: ReceiptDiscountType.percentage,
      discountPercent: 0,
      discountFixedAmount: 0,
      taxPercent: 0,
      date: now,
    );
  }

  void applyProfile({
    required String companyName,
    required String companyAddress,
    required String companyPhone,
  }) {
    if (state.companyName.isNotEmpty ||
        state.companyAddress.isNotEmpty ||
        state.companyPhone.isNotEmpty) {
      return;
    }
    state = state.copyWith(
      companyName: companyName,
      companyAddress: companyAddress,
      companyPhone: companyPhone,
    );
  }

  void updateCompanyName(String value) {
    state = state.copyWith(companyName: value);
  }

  void updateCompanyAddress(String value) {
    state = state.copyWith(companyAddress: value);
  }

  void updateCompanyPhone(String value) {
    state = state.copyWith(companyPhone: value);
  }

  void updateCustomerName(String value) {
    state = state.copyWith(customerName: value);
  }

  void updateCustomerPhone(String value) {
    state = state.copyWith(customerPhone: value);
  }

  void setCompanyProfile({
    required String companyName,
    required String companyAddress,
    required String companyPhone,
  }) {
    state = state.copyWith(
      companyName: companyName,
      companyAddress: companyAddress,
      companyPhone: companyPhone,
    );
  }

  void selectCustomer(Customer? customer) {
    state = state.copyWith(
      customerId: customer?.customerId ?? '',
      customerName: customer?.name ?? '',
      customerPhone: customer?.phone ?? '',
    );
  }

  void updateReceiptNumber(String value) {
    state = state.copyWith(receiptNumber: value);
  }

  void updatePaymentMethod(PaymentMethod value) {
    state = state.copyWith(paymentMethod: value);
  }

  void updateDiscountPercent(double value) {
    state = state.copyWith(discountPercent: value.clamp(0, 100).toDouble());
  }

  void updateDiscountType(ReceiptDiscountType value) {
    state = state.copyWith(discountType: value);
  }

  void updateDiscountFixedAmount(double value) {
    state = state.copyWith(discountFixedAmount: value < 0 ? 0 : value);
  }

  void updateTaxPercent(double value) {
    state = state.copyWith(taxPercent: value.clamp(0, 100).toDouble());
  }

  void addItem() {
    state = state.copyWith(
      items: [
        ...state.items,
        ReceiptItem(
          id: _uuid.v4(),
          productId: '',
          description: '',
          quantity: 1,
          price: 0,
          purchasePrice: 0,
        ),
      ],
    );
  }

  void removeItem(String id) {
    if (state.items.length == 1) return;
    state = state.copyWith(
      items: state.items.where((item) => item.id != id).toList(),
    );
  }

  void updateItemDescription(String id, String value) {
    _updateItem(id, (item) => item.copyWith(description: value));
  }

  void updateItemProduct(String id, Product? product) {
    _updateItem(
      id,
      (item) => item.copyWith(
        productId: product?.productId ?? '',
        description: product?.nameEn ?? '',
        price: product?.sellingPrice ?? 0,
        purchasePrice: product?.purchasePrice ?? 0,
      ),
    );
  }

  void updateItemQuantity(String id, String value) {
    final quantity = double.tryParse(value);
    _updateItem(id, (item) => item.copyWith(quantity: quantity ?? 0));
  }

  void updateItemPrice(String id, String value) {
    final price = double.tryParse(value);
    _updateItem(id, (item) => item.copyWith(price: price ?? 0));
  }

  void reset() {
    state = _initialReceipt();
  }

  void _updateItem(String id, ReceiptItem Function(ReceiptItem item) update) {
    state = state.copyWith(
      items: [
        for (final item in state.items) item.id == id ? update(item) : item,
      ],
    );
  }
}

final receiptCheckoutServiceProvider = Provider<ReceiptCheckoutService>(
  (ref) => ReceiptCheckoutService(ref, const Uuid()),
);

class ReceiptCheckoutService {
  ReceiptCheckoutService(this._ref, this._uuid);

  final Ref _ref;
  final Uuid _uuid;

  Future<Sale> checkout(Receipt receipt) async {
    if (receipt.items.isEmpty) {
      throw StateError('Add at least one item before checkout.');
    }

    final now = DateTime.now();
    final saleItems = [
      for (final item in receipt.items)
        SaleItem(
          productId: item.productId,
          name: item.description,
          qty: item.quantity,
          unitPrice: item.price,
          purchasePrice: item.purchasePrice,
        ),
    ];

    final sale = Sale(
      saleId: _uuid.v4(),
      customerId: receipt.customerId,
      items: saleItems,
      discount: receipt.discountAmount,
      totalAmount: receipt.total,
      paidAmount: receipt.total,
      dueAmount: 0,
      paymentStatus: PaymentStatus.paid,
      shopId: _ref.read(shopIdProvider),
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.pending,
    );

    final db = _ref.read(localDatabaseProvider);
    await db.sales.put(sale);
    for (final item in saleItems) {
      await _ref.read(productServiceProvider).adjustStock(
            item.productId,
            -item.qty.round(),
            syncAfterSave: false,
          );
    }
    if (receipt.customerId.isNotEmpty) {
      await db.payments.put(
        Payment(
          paymentId: _uuid.v4(),
          customerId: receipt.customerId,
          saleId: sale.saleId,
          amount: receipt.total,
          paymentMethod: receipt.paymentMethod,
          shopId: sale.shopId,
          createdAt: now,
          updatedAt: now,
          syncStatus: SyncStatus.pending,
        ),
      );
    }
    await _ref.read(syncStateProvider.notifier).syncIfOnline();
    return sale;
  }

}
