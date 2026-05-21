import '../utils/date_time_json.dart';
import 'syncable.dart';

class Supplier with Syncable {
  const Supplier({
    required this.supplierId,
    required this.name,
    required this.phone,
    required this.shopId,
    required this.updatedAt,
    this.isDeleted = false,
    this.syncStatus = SyncStatus.pending,
  });

  final String supplierId;
  final String name;
  final String phone;
  @override
  final String shopId;
  @override
  final DateTime updatedAt;
  final bool isDeleted;
  @override
  final SyncStatus syncStatus;

  @override
  String get id => supplierId;

  @override
  Map<String, dynamic> toJson() => {
    'supplierId': supplierId,
    'name': name,
    'phone': phone,
    'shopId': shopId,
    'updatedAt': dateToJson(updatedAt),
    'isDeleted': isDeleted,
    'syncStatus': syncStatus.value,
  };

  factory Supplier.fromJson(Map<dynamic, dynamic> json) => Supplier(
    supplierId: json['supplierId'] as String,
    name: (json['name'] ?? '') as String,
    phone: (json['phone'] ?? '') as String,
    shopId: (json['shopId'] ?? '') as String,
    updatedAt: dateFromJson(json['updatedAt']),
    isDeleted: json['isDeleted'] == true,
    syncStatus: SyncStatusX.parse(json['syncStatus']),
  );
}

class PurchaseItem {
  const PurchaseItem({
    required this.productId,
    required this.name,
    required this.qty,
    required this.unitCost,
  });

  final String productId;
  final String name;
  final double qty;
  final double unitCost;

  double get lineTotal => qty * unitCost;

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'name': name,
    'qty': qty,
    'unitCost': unitCost,
  };

  factory PurchaseItem.fromJson(Map<dynamic, dynamic> json) => PurchaseItem(
    productId: json['productId'] as String,
    name: (json['name'] ?? '') as String,
    qty: (json['qty'] as num? ?? 0).toDouble(),
    unitCost: (json['unitCost'] as num? ?? 0).toDouble(),
  );
}

class Purchase with Syncable {
  const Purchase({
    required this.purchaseId,
    required this.supplierId,
    required this.items,
    required this.totalAmount,
    required this.paidAmount,
    required this.shopId,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.syncStatus = SyncStatus.pending,
  });

  final String purchaseId;
  final String supplierId;
  final List<PurchaseItem> items;
  final double totalAmount;
  final double paidAmount;
  @override
  final String shopId;
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  final bool isDeleted;
  @override
  final SyncStatus syncStatus;

  @override
  String get id => purchaseId;

  double get dueAmount => totalAmount - paidAmount;

  @override
  Map<String, dynamic> toJson() => {
    'purchaseId': purchaseId,
    'supplierId': supplierId,
    'items': items.map((item) => item.toJson()).toList(),
    'totalAmount': totalAmount,
    'paidAmount': paidAmount,
    'shopId': shopId,
    'createdAt': dateToJson(createdAt),
    'updatedAt': dateToJson(updatedAt),
    'isDeleted': isDeleted,
    'syncStatus': syncStatus.value,
  };

  factory Purchase.fromJson(Map<dynamic, dynamic> json) => Purchase(
    purchaseId: json['purchaseId'] as String,
    supplierId: (json['supplierId'] ?? '') as String,
    items: ((json['items'] as List?) ?? const [])
        .map(
          (item) =>
              PurchaseItem.fromJson(Map<dynamic, dynamic>.from(item as Map)),
        )
        .toList(),
    totalAmount: (json['totalAmount'] as num? ?? 0).toDouble(),
    paidAmount: (json['paidAmount'] as num? ?? 0).toDouble(),
    shopId: (json['shopId'] ?? '') as String,
    createdAt: dateFromJson(json['createdAt']),
    updatedAt: dateFromJson(json['updatedAt']),
    isDeleted: json['isDeleted'] == true,
    syncStatus: SyncStatusX.parse(json['syncStatus']),
  );
}
