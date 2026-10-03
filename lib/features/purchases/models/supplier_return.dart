import '../../../core/models/syncable.dart';
import '../../../core/utils/date_time_json.dart';

class SupplierReturnItem {
  const SupplierReturnItem({required this.productId, required this.name, required this.qty, required this.unitCost});
  final String productId;
  final String name;
  final double qty;
  final double unitCost;
  Map<String, dynamic> toJson() => {'productId': productId, 'name': name, 'qty': qty, 'unitCost': unitCost};
  factory SupplierReturnItem.fromJson(Map<dynamic, dynamic> json) => SupplierReturnItem(
        productId: (json['productId'] ?? '') as String,
        name: (json['name'] ?? '') as String,
        qty: (json['qty'] as num? ?? 0).toDouble(),
        unitCost: (json['unitCost'] as num? ?? 0).toDouble(),
      );
}

class SupplierReturn with Syncable {
  const SupplierReturn({
    required this.returnId,
    required this.orderId,
    required this.supplierId,
    required this.items,
    required this.totalAmount,
    required this.reason,
    required this.actorId,
    required this.shopId,
    this.branchId,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.syncStatus = SyncStatus.pending,
  });
  final String returnId;
  final String orderId;
  final String supplierId;
  final List<SupplierReturnItem> items;
  final double totalAmount;
  final String reason;
  final String actorId;
  @override final String shopId;
  final String? branchId;
  final DateTime createdAt;
  @override final DateTime updatedAt;
  final bool isDeleted;
  @override final SyncStatus syncStatus;
  @override String get id => returnId;

  @override
  Map<String, dynamic> toJson() => {
        'returnId': returnId,
        'orderId': orderId,
        'supplierId': supplierId,
        'items': items.map((item) => item.toJson()).toList(),
        'totalAmount': totalAmount,
        'reason': reason,
        'actorId': actorId,
        'shopId': shopId,
        'branchId': branchId,
        'createdAt': dateToJson(createdAt),
        'updatedAt': dateToJson(updatedAt),
        'isDeleted': isDeleted,
        'syncStatus': syncStatus.value,
      };

  factory SupplierReturn.fromJson(Map<dynamic, dynamic> json) => SupplierReturn(
        returnId: (json['returnId'] ?? '') as String,
        orderId: (json['orderId'] ?? '') as String,
        supplierId: (json['supplierId'] ?? '') as String,
        items: ((json['items'] as List?) ?? const []).whereType<Map>().map(SupplierReturnItem.fromJson).toList(),
        totalAmount: (json['totalAmount'] as num? ?? 0).toDouble(),
        reason: (json['reason'] ?? '') as String,
        actorId: (json['actorId'] ?? '') as String,
        shopId: (json['shopId'] ?? '') as String,
        branchId: (json['branchId'] ?? '${(json['shopId'] ?? '') as String}-main') as String,
        createdAt: dateFromJson(json['createdAt']),
        updatedAt: dateFromJson(json['updatedAt']),
        isDeleted: json['isDeleted'] == true,
        syncStatus: SyncStatusX.parse(json['syncStatus']),
      );
}
