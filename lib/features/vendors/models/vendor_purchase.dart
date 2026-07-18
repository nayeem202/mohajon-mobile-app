import '../../../core/utils/date_time_json.dart';
import '../../../core/models/syncable.dart';

class VendorPurchase with Syncable {
  const VendorPurchase({
    required this.purchaseId,
    required this.vendorId,
    required this.amount,
    required this.date,
    this.status = 'pending',
    this.notes = '',
    this.itemsSupplied = '',
    required this.shopId,
    required this.updatedAt,
    this.isDeleted = false,
    this.syncStatus = SyncStatus.pending,
  });

  final String purchaseId;
  final String vendorId;
  final double amount;
  final DateTime date;
  final String status;
  final String notes;
  final String itemsSupplied;
  @override
  final String shopId;
  @override
  final DateTime updatedAt;
  final bool isDeleted;
  @override
  final SyncStatus syncStatus;

  @override
  String get id => purchaseId;

  VendorPurchase copyWith({
    String? purchaseId,
    String? vendorId,
    double? amount,
    DateTime? date,
    String? status,
    String? notes,
    String? itemsSupplied,
    String? shopId,
    DateTime? updatedAt,
    bool? isDeleted,
    SyncStatus? syncStatus,
  }) {
    return VendorPurchase(
      purchaseId: purchaseId ?? this.purchaseId,
      vendorId: vendorId ?? this.vendorId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      itemsSupplied: itemsSupplied ?? this.itemsSupplied,
      shopId: shopId ?? this.shopId,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'purchaseId': purchaseId,
    'vendorId': vendorId,
    'amount': amount,
    'date': dateToJson(date),
    'status': status,
    'notes': notes,
    'itemsSupplied': itemsSupplied,
    'shopId': shopId,
    'updatedAt': dateToJson(updatedAt),
    'isDeleted': isDeleted,
    'syncStatus': syncStatus.value,
  };

  factory VendorPurchase.fromJson(Map<dynamic, dynamic> json) => VendorPurchase(
    purchaseId: json['purchaseId'] as String,
    vendorId: (json['vendorId'] ?? '') as String,
    amount: (json['amount'] as num? ?? 0).toDouble(),
    date: dateFromJson(json['date']),
    status: (json['status'] ?? 'pending') as String,
    notes: (json['notes'] ?? '') as String,
    itemsSupplied: (json['itemsSupplied'] ?? '') as String,
    shopId: (json['shopId'] ?? '') as String,
    updatedAt: dateFromJson(json['updatedAt']),
    isDeleted: json['isDeleted'] == true,
    syncStatus: SyncStatusX.parse(json['syncStatus']),
  );
}
