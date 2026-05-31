import 'package:intl/intl.dart';

const receiptPaymentMethods = ['Cash', 'bKash', 'Nagad'];

final _receiptCurrency = NumberFormat.currency(locale: 'en_US', symbol: r'$');

String receiptMoney(num value) => _receiptCurrency.format(value);

enum ReceiptDiscountType { percentage, fixedAmount }

class ReceiptItem {
  const ReceiptItem({
    required this.id,
    required this.productId,
    required this.description,
    required this.quantity,
    required this.price,
    required this.purchasePrice,
  });

  final String id;
  final String productId;
  final String description;
  final double quantity;
  final double price;
  final double purchasePrice;

  double get total => quantity * price;

  ReceiptItem copyWith({
    String? productId,
    String? description,
    double? quantity,
    double? price,
    double? purchasePrice,
  }) {
    return ReceiptItem(
      id: id,
      productId: productId ?? this.productId,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      purchasePrice: purchasePrice ?? this.purchasePrice,
    );
  }
}

class Receipt {
  const Receipt({
    required this.companyName,
    required this.companyAddress,
    required this.companyPhone,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.receiptNumber,
    required this.paymentMethod,
    required this.items,
    required this.discountType,
    required this.discountPercent,
    required this.discountFixedAmount,
    required this.taxPercent,
    required this.date,
  });

  final String companyName;
  final String companyAddress;
  final String companyPhone;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String receiptNumber;
  final String paymentMethod;
  final List<ReceiptItem> items;
  final ReceiptDiscountType discountType;
  final double discountPercent;
  final double discountFixedAmount;
  final double taxPercent;
  final DateTime date;

  String get displayPaymentMethod => paymentMethod;

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.total);

  double get discountAmount {
    final rawDiscount = switch (discountType) {
      ReceiptDiscountType.percentage => subtotal * (discountPercent / 100),
      ReceiptDiscountType.fixedAmount => discountFixedAmount,
    };
    return rawDiscount.clamp(0, subtotal).toDouble();
  }

  double get subtotalAfterDiscount => subtotal - discountAmount;

  double get taxAmount => subtotalAfterDiscount * (taxPercent / 100);

  double get total => subtotalAfterDiscount + taxAmount;

  String get safeReceiptNumber {
    return receiptNumber.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-');
  }

  Receipt copyWith({
    String? companyName,
    String? companyAddress,
    String? companyPhone,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? receiptNumber,
    String? paymentMethod,
    List<ReceiptItem>? items,
    ReceiptDiscountType? discountType,
    double? discountPercent,
    double? discountFixedAmount,
    double? taxPercent,
    DateTime? date,
  }) {
    return Receipt(
      companyName: companyName ?? this.companyName,
      companyAddress: companyAddress ?? this.companyAddress,
      companyPhone: companyPhone ?? this.companyPhone,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      items: items ?? this.items,
      discountType: discountType ?? this.discountType,
      discountPercent: discountPercent ?? this.discountPercent,
      discountFixedAmount: discountFixedAmount ?? this.discountFixedAmount,
      taxPercent: taxPercent ?? this.taxPercent,
      date: date ?? this.date,
    );
  }
}
