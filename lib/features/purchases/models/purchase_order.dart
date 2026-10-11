import '../../../core/utils/date_time_json.dart';
import '../../../core/models/syncable.dart';
import 'purchase_receipt.dart';

class PurchaseOrderItem {
  const PurchaseOrderItem({
    required this.productId,
    required this.name,
    required this.qty,
    required this.unitCost,
    this.batchNumber = '',
    this.expiryDate,
  });

  final String productId;
  final String name;
  final double qty;
  final double unitCost;
  final String batchNumber;
  final DateTime? expiryDate;

  double get total => qty * unitCost;

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'name': name,
    'qty': qty,
    'unitCost': unitCost,
    'batchNumber': batchNumber,
    'expiryDate': expiryDate == null ? null : dateToJson(expiryDate!),
  };

  factory PurchaseOrderItem.fromJson(Map<dynamic, dynamic> json) =>
      PurchaseOrderItem(
        productId: (json['productId'] ?? '') as String,
        name: (json['name'] ?? '') as String,
        qty: (json['qty'] as num? ?? 0).toDouble(),
        unitCost: (json['unitCost'] as num? ?? 0).toDouble(),
        batchNumber: (json['batchNumber'] ?? '') as String,
        expiryDate: json['expiryDate'] == null
            ? null
            : dateFromJson(json['expiryDate']),
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
    this.branchId,
    required this.createdAt,
    required this.updatedAt,
    this.notes = '',
    this.isDeleted = false,
    this.synced = false,
    this.receivedQty = const {},
    this.deliveredQty = const {},
    this.receipts = const [],
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
  final String? branchId;
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  final bool isDeleted;
  final bool synced;

  /// Cumulative received quantity by product ID. Keeps partial receiving
  /// idempotent at the order level and survives offline sync.
  final Map<String, double> receivedQty;

  /// Physically delivered quantities, including damaged goods. receivedQty
  /// remains the accepted/in-stock quantity for backwards compatibility.
  final Map<String, double> deliveredQty;
  final List<PurchaseReceipt> receipts;
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
    'branchId': branchId,
    'createdAt': dateToJson(createdAt),
    'updatedAt': dateToJson(updatedAt),
    'isDeleted': isDeleted,
    'synced': synced,
    'receivedQty': receivedQty,
    'deliveredQty': deliveredQty,
    'receipts': receipts.map((receipt) => receipt.toJson()).toList(),
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
    branchId:
        (json['branchId'] ?? '${(json['shopId'] ?? '') as String}-main')
            as String,
    createdAt: dateFromJson(json['createdAt']),
    updatedAt: dateFromJson(json['updatedAt']),
    isDeleted: json['isDeleted'] == true,
    synced: json['synced'] == true,
    receivedQty: (json['receivedQty'] is Map)
        ? Map<String, double>.from(
            (json['receivedQty'] as Map).map(
              (key, value) =>
                  MapEntry(key.toString(), (value as num).toDouble()),
            ),
          )
        : const {},
    deliveredQty: (json['deliveredQty'] is Map)
        ? Map<String, double>.from(
            (json['deliveredQty'] as Map).map(
              (key, value) =>
                  MapEntry(key.toString(), (value as num).toDouble()),
            ),
          )
        : (json['receivedQty'] is Map)
        ? Map<String, double>.from(
            (json['receivedQty'] as Map).map(
              (key, value) =>
                  MapEntry(key.toString(), (value as num).toDouble()),
            ),
          )
        : const {},
    receipts: ((json['receipts'] as List?) ?? const [])
        .whereType<Map>()
        .map(PurchaseReceipt.fromJson)
        .toList(),
    syncStatus: SyncStatusX.parse(json['syncStatus']),
  );

  PurchaseOrder copyWith({
    String? shopId,
    String? branchId,
    bool? synced,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
    String? status,
    Map<String, double>? receivedQty,
    Map<String, double>? deliveredQty,
    List<PurchaseReceipt>? receipts,
  }) => PurchaseOrder(
    orderId: orderId,
    supplierId: supplierId,
    items: items,
    totalAmount: totalAmount,
    status: status ?? this.status,
    notes: notes,
    shopId: shopId ?? this.shopId,
    branchId: branchId ?? this.branchId,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isDeleted: isDeleted,
    synced: synced ?? this.synced,
    syncStatus: syncStatus ?? this.syncStatus,
    receivedQty: receivedQty ?? this.receivedQty,
    deliveredQty: deliveredQty ?? this.deliveredQty,
    receipts: receipts ?? this.receipts,
  );
}
