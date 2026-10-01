import '../utils/date_time_json.dart';
import 'payment.dart';
import 'syncable.dart';

enum PaymentStatus { paid, partial, due }

extension PaymentStatusX on PaymentStatus {
  String get value => name.toUpperCase();

  static PaymentStatus parse(Object? value) {
    final normalized = value.toString().toLowerCase();
    return PaymentStatus.values.firstWhere(
      (status) => status.name == normalized,
      orElse: () => PaymentStatus.due,
    );
  }
}

class SaleItem {
  const SaleItem({
    required this.productId,
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.purchasePrice,
  });

  final String productId;
  final String name;
  final double qty;
  final double unitPrice;
  final double purchasePrice;

  double get lineTotal => qty * unitPrice;
  double get profit => qty * (unitPrice - purchasePrice);

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'name': name,
    'qty': qty,
    'unitPrice': unitPrice,
    'purchasePrice': purchasePrice,
  };

  factory SaleItem.fromJson(Map<dynamic, dynamic> json) => SaleItem(
    productId: json['productId'] as String,
    name: (json['name'] ?? '') as String,
    qty: (json['qty'] as num? ?? 0).toDouble(),
    unitPrice: (json['unitPrice'] as num? ?? 0).toDouble(),
    purchasePrice: (json['purchasePrice'] as num? ?? 0).toDouble(),
  );
}

class Sale with Syncable {
  const Sale({
    required this.saleId,
    required this.customerId,
    required this.items,
    required this.totalAmount,
    required this.paidAmount,
    required this.dueAmount,
    required this.paymentStatus,
    required this.shopId,
    required this.createdAt,
    required this.updatedAt,
    this.discount = 0,
    this.vatPercent = 0,
    this.charge = 0,
    this.paymentMethod = PaymentMethod.cash,
    this.staffId,
    this.isDeleted = false,
    this.syncStatus = SyncStatus.pending,
  });

  final String saleId;
  final String customerId;
  final List<SaleItem> items;
  final double discount;
  final double vatPercent;
  final double charge;
  final PaymentMethod paymentMethod;
  final String? staffId;
  final double totalAmount;
  final double paidAmount;
  final double dueAmount;
  final PaymentStatus paymentStatus;
  @override
  final String shopId;
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  final bool isDeleted;
  @override
  final SyncStatus syncStatus;

  @override
  String get id => saleId;

  double get profit =>
      items.fold<double>(0, (total, item) => total + item.profit) - discount;

  Sale copyWith({
    double? paidAmount,
    double? dueAmount,
    PaymentStatus? paymentStatus,
    PaymentMethod? paymentMethod,
    String? staffId,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
  }) {
    return Sale(
      saleId: saleId,
      customerId: customerId,
      items: items,
      discount: discount,
      vatPercent: vatPercent,
      charge: charge,
      totalAmount: totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      dueAmount: dueAmount ?? this.dueAmount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      staffId: staffId ?? this.staffId,
      shopId: shopId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'saleId': saleId,
    'customerId': customerId,
    'items': items.map((item) => item.toJson()).toList(),
    'discount': discount,
    'vatPercent': vatPercent,
    'charge': charge,
    'totalAmount': totalAmount,
    'paidAmount': paidAmount,
    'dueAmount': dueAmount,
    'paymentStatus': paymentStatus.value,
    'paymentMethod': paymentMethod.value,
    'staffId': staffId,
    'shopId': shopId,
    'createdAt': dateToJson(createdAt),
    'updatedAt': dateToJson(updatedAt),
    'isDeleted': isDeleted,
    'syncStatus': syncStatus.value,
  };

  factory Sale.fromJson(Map<dynamic, dynamic> json) => Sale(
    saleId: json['saleId'] as String,
    customerId: (json['customerId'] ?? '') as String,
    items: ((json['items'] as List?) ?? const [])
        .map(
          (item) => SaleItem.fromJson(Map<dynamic, dynamic>.from(item as Map)),
        )
        .toList(),
    discount: (json['discount'] as num? ?? 0).toDouble(),
    vatPercent: (json['vatPercent'] as num? ?? 0).toDouble(),
    charge: (json['charge'] as num? ?? 0).toDouble(),
    totalAmount: (json['totalAmount'] as num? ?? 0).toDouble(),
    paidAmount: (json['paidAmount'] as num? ?? 0).toDouble(),
    dueAmount: (json['dueAmount'] as num? ?? 0).toDouble(),
    paymentStatus: PaymentStatusX.parse(json['paymentStatus']),
    paymentMethod: PaymentMethodX.parse(json['paymentMethod']),
    staffId: json['staffId'] as String?,
    shopId: (json['shopId'] ?? '') as String,
    createdAt: dateFromJson(json['createdAt']),
    updatedAt: dateFromJson(json['updatedAt']),
    isDeleted: json['isDeleted'] == true,
    syncStatus: SyncStatusX.parse(json['syncStatus']),
  );
}
