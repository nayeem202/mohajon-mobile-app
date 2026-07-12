import '../../../core/utils/date_time_json.dart';
import '../../../core/models/syncable.dart';

class VendorPayment with Syncable {
  const VendorPayment({
    required this.paymentId,
    required this.vendorId,
    required this.amount,
    required this.date,
    this.method = 'cash',
    this.reference = '',
    this.notes = '',
    required this.shopId,
    required this.updatedAt,
    this.isDeleted = false,
    this.syncStatus = SyncStatus.pending,
  });

  final String paymentId;
  final String vendorId;
  final double amount;
  final DateTime date;
  final String method;
  final String reference;
  final String notes;
  @override
  final String shopId;
  @override
  final DateTime updatedAt;
  final bool isDeleted;
  @override
  final SyncStatus syncStatus;

  @override
  String get id => paymentId;

  VendorPayment copyWith({
    String? paymentId,
    String? vendorId,
    double? amount,
    DateTime? date,
    String? method,
    String? reference,
    String? notes,
    String? shopId,
    DateTime? updatedAt,
    bool? isDeleted,
    SyncStatus? syncStatus,
  }) {
    return VendorPayment(
      paymentId: paymentId ?? this.paymentId,
      vendorId: vendorId ?? this.vendorId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      method: method ?? this.method,
      reference: reference ?? this.reference,
      notes: notes ?? this.notes,
      shopId: shopId ?? this.shopId,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'paymentId': paymentId,
    'vendorId': vendorId,
    'amount': amount,
    'date': dateToJson(date),
    'method': method,
    'reference': reference,
    'notes': notes,
    'shopId': shopId,
    'updatedAt': dateToJson(updatedAt),
    'isDeleted': isDeleted,
    'syncStatus': syncStatus.value,
  };

  factory VendorPayment.fromJson(Map<dynamic, dynamic> json) => VendorPayment(
    paymentId: json['paymentId'] as String,
    vendorId: (json['vendorId'] ?? '') as String,
    amount: (json['amount'] as num? ?? 0).toDouble(),
    date: dateFromJson(json['date']),
    method: (json['method'] ?? 'cash') as String,
    reference: (json['reference'] ?? '') as String,
    notes: (json['notes'] ?? '') as String,
    shopId: (json['shopId'] ?? '') as String,
    updatedAt: dateFromJson(json['updatedAt']),
    isDeleted: json['isDeleted'] == true,
    syncStatus: SyncStatusX.parse(json['syncStatus']),
  );
}
