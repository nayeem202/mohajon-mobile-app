import '../../../core/utils/date_time_json.dart';
import '../../../core/models/syncable.dart';

class PurchaseOrderItem {
  const PurchaseOrderItem({
    required this.productId,
    required this.name,
    required this.qty,
    required this.unitCost,
  });

  final String productId;
  final String name;
  final double qty;
  final double unitCost;

  double get total => qty * unitCost;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'name': name,
        'qty': qty,
        'unitCost': unitCost,
      };

  factory PurchaseOrderItem.fromJson(Map<dynamic, dynamic> json) =>
      PurchaseOrderItem(
        productId: (json['productId'] ?? '') as String,
        name: (json['name'] ?? '') as String,
        qty: (json['qty'] as num? ?? 0).toDouble(),
        unitCost: (json['unitCost'] as num? ?? 0).toDouble(),
      );
}

class PurchaseOrder with Syncable {
  const PurchaseOrder({
    required this.orderId,
    required this.supplierId,
    required this.items,
    required this.totalAmount,
    required this.status,
    required this.shopId,
    required this.createdAt,
    required this.updatedAt,
    this.notes = '',
    this.isDeleted = false,
    this.synced = false,
    this.syncStatus = SyncStatus.pending,
  });

  final String orderId;
  final String supplierId;
  final List<PurchaseOrderItem> items;
  final double totalAmount;
  final String status;
  final String notes;
  @override
  final String shopId;
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  final bool isDeleted;
  final bool synced;
  @override
  final SyncStatus syncStatus;

  @override
  String get id => orderId;

  @override
  Map<String, dynamic> toJson() => {
        'orderId': orderId,
        'supplierId': supplierId,
        'items': items.map((item) => item.toJson()).toList(),
        'totalAmount': totalAmount,
        'status': status,
        'notes': notes,
        'shopId': shopId,
        'createdAt': dateToJson(createdAt),
        'updatedAt': dateToJson(updatedAt),
        'isDeleted': isDeleted,
        'synced': synced,
        'syncStatus': syncStatus.value,
      };

  factory PurchaseOrder.fromJson(Map<dynamic, dynamic> json) => PurchaseOrder(
        orderId: (json['orderId'] ?? '') as String,
        supplierId: (json['supplierId'] ?? '') as String,
        items: ((json['items'] as List?) ?? const [])
            .whereType<Map>()
            .map(PurchaseOrderItem.fromJson)
            .toList(),
        totalAmount: (json['totalAmount'] as num? ?? 0).toDouble(),
        status: (json['status'] ?? 'DRAFT') as String,
        notes: (json['notes'] ?? '') as String,
        shopId: (json['shopId'] ?? '') as String,
        createdAt: dateFromJson(json['createdAt']),
        updatedAt: dateFromJson(json['updatedAt']),
        isDeleted: json['isDeleted'] == true,
        synced: json['synced'] == true,
        syncStatus: SyncStatusX.parse(json['syncStatus']),
      );

  PurchaseOrder copyWith({
    String? shopId,
    bool? synced,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
  }) => PurchaseOrder(
        orderId: orderId,
        supplierId: supplierId,
        items: items,
        totalAmount: totalAmount,
        status: status,
        notes: notes,
        shopId: shopId ?? this.shopId,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isDeleted: isDeleted,
        synced: synced ?? this.synced,
        syncStatus: syncStatus ?? this.syncStatus,
      );
}
