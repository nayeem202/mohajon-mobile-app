import '../utils/date_time_json.dart';
import 'syncable.dart';

class SaleReturnItem {
  const SaleReturnItem({
    required this.returnItemId,
    required this.saleItemId,
    required this.productId,
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.purchasePrice,
  });

  final String returnItemId;
  final String saleItemId;
  final String productId;
  final String name;
  final double qty;
  final double unitPrice;
  final double purchasePrice;

  Map<String, dynamic> toJson() => {
    'returnItemId': returnItemId,
    'saleItemId': saleItemId,
    'productId': productId,
    'name': name,
    'qty': qty,
    'unitPrice': unitPrice,
    'purchasePrice': purchasePrice,
  };

  factory SaleReturnItem.fromJson(Map<dynamic, dynamic> json) => SaleReturnItem(
    returnItemId: (json['returnItemId'] ?? '') as String,
    saleItemId: (json['saleItemId'] ?? '') as String,
    productId: (json['productId'] ?? '') as String,
    name: (json['name'] ?? '') as String,
    qty: (json['qty'] as num? ?? 0).toDouble(),
    unitPrice: (json['unitPrice'] as num? ?? 0).toDouble(),
    purchasePrice: (json['purchasePrice'] as num? ?? 0).toDouble(),
  );
}

class SaleReturn with Syncable {
  const SaleReturn({
    required this.returnId,
    required this.saleId,
    required this.customerId,
    required this.items,
    required this.refundAmount,
    required this.refundMethod,
    required this.reason,
    required this.staffId,
    required this.branchId,
    required this.shopId,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.syncStatus = SyncStatus.pending,
  });

  final String returnId;
  final String saleId;
  final String customerId;
  final List<SaleReturnItem> items;
  final double refundAmount;
  final String refundMethod;
  final String reason;
  final String? staffId;
  final String branchId;
  @override
  final String shopId;
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  final bool isDeleted;
  @override
  final SyncStatus syncStatus;

  @override
  String get id => returnId;

  @override
  Map<String, dynamic> toJson() => {
    'returnId': returnId,
    'saleId': saleId,
    'customerId': customerId,
    'items': items.map((item) => item.toJson()).toList(),
    'refundAmount': refundAmount,
    'refundMethod': refundMethod,
    'reason': reason,
    'staffId': staffId,
    'branchId': branchId,
    'shopId': shopId,
    'createdAt': dateToJson(createdAt),
    'updatedAt': dateToJson(updatedAt),
    'isDeleted': isDeleted,
    'syncStatus': syncStatus.value,
  };

  factory SaleReturn.fromJson(Map<dynamic, dynamic> json) => SaleReturn(
    returnId: (json['returnId'] ?? '') as String,
    saleId: (json['saleId'] ?? '') as String,
    customerId: (json['customerId'] ?? '') as String,
    items: ((json['items'] as List?) ?? const [])
        .whereType<Map>()
        .map(SaleReturnItem.fromJson)
        .toList(),
    refundAmount: (json['refundAmount'] as num? ?? 0).toDouble(),
    refundMethod: (json['refundMethod'] ?? 'CASH') as String,
    reason: (json['reason'] ?? '') as String,
    staffId: json['staffId'] as String?,
    branchId:
        (json['branchId'] ?? '${(json['shopId'] ?? '') as String}-main')
            as String,
    shopId: (json['shopId'] ?? '') as String,
    createdAt: dateFromJson(json['createdAt']),
    updatedAt: dateFromJson(json['updatedAt']),
    isDeleted: json['isDeleted'] == true,
    syncStatus: SyncStatusX.parse(json['syncStatus']),
  );
}
