import '../utils/date_time_json.dart';
import 'syncable.dart';

enum StockAdjustmentStatus { pendingApproval, approved, rejected }

class StockAdjustment with Syncable {
  const StockAdjustment({
    required this.adjustmentId,
    required this.productId,
    required this.delta,
    required this.reason,
    required this.actorId,
    required this.shopId,
    this.branchId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.approverId,
    this.isDeleted = false,
    this.syncStatus = SyncStatus.pending,
  });

  final String adjustmentId;
  final String productId;
  final int delta;
  final String reason;
  final String actorId;
  final String? approverId;
  @override
  final String shopId;
  final String? branchId;
  final StockAdjustmentStatus status;
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  final bool isDeleted;
  @override
  final SyncStatus syncStatus;

  @override
  String get id => adjustmentId;

  StockAdjustment copyWith({
    StockAdjustmentStatus? status,
    String? approverId,
    DateTime? updatedAt,
    bool? isDeleted,
    SyncStatus? syncStatus,
  }) => StockAdjustment(
        adjustmentId: adjustmentId,
        productId: productId,
        delta: delta,
        reason: reason,
        actorId: actorId,
        approverId: approverId ?? this.approverId,
        shopId: shopId,
        branchId: branchId,
        status: status ?? this.status,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isDeleted: isDeleted ?? this.isDeleted,
        syncStatus: syncStatus ?? this.syncStatus,
      );

  @override
  Map<String, dynamic> toJson() => {
        'adjustmentId': adjustmentId,
        'productId': productId,
        'delta': delta,
        'reason': reason,
        'actorId': actorId,
        'approverId': approverId,
        'shopId': shopId,
        'branchId': branchId,
        'status': status.name,
        'createdAt': dateToJson(createdAt),
        'updatedAt': dateToJson(updatedAt),
        'isDeleted': isDeleted,
        'syncStatus': syncStatus.value,
      };

  factory StockAdjustment.fromJson(Map<dynamic, dynamic> json) =>
      StockAdjustment(
        adjustmentId: (json['adjustmentId'] ?? '') as String,
        productId: (json['productId'] ?? '') as String,
        delta: (json['delta'] as num? ?? 0).toInt(),
        reason: (json['reason'] ?? '') as String,
        actorId: (json['actorId'] ?? '') as String,
        approverId: json['approverId'] as String?,
        shopId: (json['shopId'] ?? '') as String,
        branchId: (json['branchId'] ?? '${(json['shopId'] ?? '') as String}-main') as String,
        status: StockAdjustmentStatus.values.firstWhere(
          (value) => value.name == json['status'],
          orElse: () => StockAdjustmentStatus.pendingApproval,
        ),
        createdAt: dateFromJson(json['createdAt']),
        updatedAt: dateFromJson(json['updatedAt']),
        isDeleted: json['isDeleted'] == true,
        syncStatus: SyncStatusX.parse(json['syncStatus']),
      );
}
