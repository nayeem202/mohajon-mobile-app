import '../utils/date_time_json.dart';
import 'syncable.dart';

class ProductBatch with Syncable {
  const ProductBatch({
    required this.batchId,
    required this.productId,
    required this.batchNumber,
    required this.quantity,
    required this.unitCost,
    required this.shopId,
    required this.branchId,
    required this.updatedAt,
    this.expiryDate,
    this.isDeleted = false,
    this.syncStatus = SyncStatus.pending,
  });

  final String batchId;
  final String productId;
  final String batchNumber;
  final DateTime? expiryDate;
  final int quantity;
  final double unitCost;
  @override
  final String shopId;
  final String branchId;
  @override
  final DateTime updatedAt;
  final bool isDeleted;
  @override
  final SyncStatus syncStatus;

  @override
  String get id => batchId;

  ProductBatch copyWith({
    int? quantity,
    DateTime? updatedAt,
    bool? isDeleted,
    SyncStatus? syncStatus,
  }) => ProductBatch(
        batchId: batchId,
        productId: productId,
        batchNumber: batchNumber,
        expiryDate: expiryDate,
        quantity: quantity ?? this.quantity,
        unitCost: unitCost,
        shopId: shopId,
        branchId: branchId,
        updatedAt: updatedAt ?? this.updatedAt,
        isDeleted: isDeleted ?? this.isDeleted,
        syncStatus: syncStatus ?? this.syncStatus,
      );

  @override
  Map<String, dynamic> toJson() => {
        'batchId': batchId,
        'productId': productId,
        'batchNumber': batchNumber,
        'expiryDate': expiryDate == null ? null : dateToJson(expiryDate!),
        'quantity': quantity,
        'unitCost': unitCost,
        'shopId': shopId,
        'branchId': branchId,
        'updatedAt': dateToJson(updatedAt),
        'isDeleted': isDeleted,
        'syncStatus': syncStatus.value,
      };

  factory ProductBatch.fromJson(Map<dynamic, dynamic> json) => ProductBatch(
        batchId: (json['batchId'] ?? '') as String,
        productId: (json['productId'] ?? '') as String,
        batchNumber: (json['batchNumber'] ?? '') as String,
        expiryDate: json['expiryDate'] == null ? null : dateFromJson(json['expiryDate']),
        quantity: (json['quantity'] as num? ?? 0).toInt(),
        unitCost: (json['unitCost'] as num? ?? 0).toDouble(),
        shopId: (json['shopId'] ?? '') as String,
        branchId: (json['branchId'] ?? '${(json['shopId'] ?? '') as String}-main') as String,
        updatedAt: dateFromJson(json['updatedAt']),
        isDeleted: json['isDeleted'] == true,
        syncStatus: SyncStatusX.parse(json['syncStatus']),
      );
}
