import '../utils/date_time_json.dart';
import 'syncable.dart';

enum PaymentMethod {
  cash,
  bkash,
  nagad,
  credit,
  bank,
  other;

  String get displayName {
    switch (this) {
      case PaymentMethod.cash: return 'Cash';
      case PaymentMethod.bkash: return 'bKash';
      case PaymentMethod.nagad: return 'Nagad';
      case PaymentMethod.credit: return 'Credit';
      case PaymentMethod.bank: return 'Bank';
      case PaymentMethod.other: return 'Other';
    }
  }
}

extension PaymentMethodX on PaymentMethod {
  String get value => name.toUpperCase();

  static PaymentMethod parse(Object? value) {
    final normalized = value.toString().toLowerCase();
    return PaymentMethod.values.firstWhere(
      (method) => method.name == normalized,
      orElse: () => PaymentMethod.cash,
    );
  }
}

class Payment with Syncable {
  const Payment({
    required this.paymentId,
    required this.customerId,
    required this.amount,
    required this.paymentMethod,
    required this.shopId,
    required this.createdAt,
    required this.updatedAt,
    this.saleId,
    this.isDeleted = false,
    this.syncStatus = SyncStatus.pending,
  });

  final String paymentId;
  final String customerId;
  final String? saleId;
  final double amount;
  final PaymentMethod paymentMethod;
  @override
  final String shopId;
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  final bool isDeleted;
  @override
  final SyncStatus syncStatus;

  @override
  String get id => paymentId;

  @override
  Map<String, dynamic> toJson() => {
    'paymentId': paymentId,
    'customerId': customerId,
    'saleId': saleId,
    'amount': amount,
    'paymentMethod': paymentMethod.value,
    'shopId': shopId,
    'createdAt': dateToJson(createdAt),
    'updatedAt': dateToJson(updatedAt),
    'isDeleted': isDeleted,
    'syncStatus': syncStatus.value,
  };

  factory Payment.fromJson(Map<dynamic, dynamic> json) => Payment(
    paymentId: json['paymentId'] as String,
    customerId: (json['customerId'] ?? '') as String,
    saleId: json['saleId'] as String?,
    amount: (json['amount'] as num? ?? 0).toDouble(),
    paymentMethod: PaymentMethodX.parse(json['paymentMethod']),
    shopId: (json['shopId'] ?? '') as String,
    createdAt: dateFromJson(json['createdAt']),
    updatedAt: dateFromJson(json['updatedAt']),
    isDeleted: json['isDeleted'] == true,
    syncStatus: SyncStatusX.parse(json['syncStatus']),
  );
}
