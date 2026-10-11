import '../../../core/utils/date_time_json.dart';

class PurchaseReceiptItem {
  const PurchaseReceiptItem({
    required this.productId,
    required this.orderedQty,
    required this.deliveredQty,
    required this.acceptedQty,
    required this.damagedQty,
    required this.unitCost,
    this.orderedUnitCost = 0,
    this.issueNote = '',
  });

  final String productId;
  final double orderedQty;
  final double deliveredQty;
  final double acceptedQty;
  final double damagedQty;
  final double unitCost;
  final double orderedUnitCost;
  final String issueNote;

  double get shortQty => (orderedQty - deliveredQty).clamp(0, double.infinity);

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'orderedQty': orderedQty,
    'deliveredQty': deliveredQty,
    'acceptedQty': acceptedQty,
    'damagedQty': damagedQty,
    'shortQty': shortQty,
    'unitCost': unitCost,
    'orderedUnitCost': orderedUnitCost,
    'issueNote': issueNote,
  };

  factory PurchaseReceiptItem.fromJson(Map<dynamic, dynamic> json) =>
      PurchaseReceiptItem(
        productId: (json['productId'] ?? '') as String,
        orderedQty: (json['orderedQty'] as num? ?? 0).toDouble(),
        deliveredQty: (json['deliveredQty'] as num? ?? 0).toDouble(),
        acceptedQty: (json['acceptedQty'] as num? ?? 0).toDouble(),
        damagedQty: (json['damagedQty'] as num? ?? 0).toDouble(),
        unitCost: (json['unitCost'] as num? ?? 0).toDouble(),
        orderedUnitCost:
            (json['orderedUnitCost'] as num? ?? json['unitCost'] as num? ?? 0)
                .toDouble(),
        issueNote: (json['issueNote'] ?? '') as String,
      );
}

class PurchaseReceipt {
  const PurchaseReceipt({
    required this.receiptId,
    required this.receivedAt,
    required this.items,
    required this.invoiceAmount,
    this.invoiceNumber = '',
    this.freightAmount = 0,
    this.discountAmount = 0,
    this.attachmentPath = '',
    this.notes = '',
  });

  final String receiptId;
  final DateTime receivedAt;
  final List<PurchaseReceiptItem> items;
  final double invoiceAmount;
  final String invoiceNumber;
  final double freightAmount;
  final double discountAmount;

  /// Local durable path while offline; remote URL after successful upload.
  final String attachmentPath;
  final String notes;

  double get expectedAmount =>
      items.fold<double>(
        0,
        (sum, item) => sum + item.acceptedQty * item.orderedUnitCost,
      ) +
      freightAmount -
      discountAmount;

  double get invoiceVariance => invoiceAmount - expectedAmount;

  Map<String, dynamic> toJson() => {
    'receiptId': receiptId,
    'receivedAt': dateToJson(receivedAt),
    'items': items.map((item) => item.toJson()).toList(),
    'invoiceAmount': invoiceAmount,
    'invoiceNumber': invoiceNumber,
    'freightAmount': freightAmount,
    'discountAmount': discountAmount,
    'attachmentPath': attachmentPath,
    'expectedAmount': expectedAmount,
    'invoiceVariance': invoiceVariance,
    'notes': notes,
  };

  factory PurchaseReceipt.fromJson(Map<dynamic, dynamic> json) =>
      PurchaseReceipt(
        receiptId: (json['receiptId'] ?? '') as String,
        receivedAt: dateFromJson(json['receivedAt']),
        items: ((json['items'] as List?) ?? const [])
            .whereType<Map>()
            .map(PurchaseReceiptItem.fromJson)
            .toList(),
        invoiceAmount: (json['invoiceAmount'] as num? ?? 0).toDouble(),
        invoiceNumber: (json['invoiceNumber'] ?? '') as String,
        freightAmount: (json['freightAmount'] as num? ?? 0).toDouble(),
        discountAmount: (json['discountAmount'] as num? ?? 0).toDouble(),
        attachmentPath: (json['attachmentPath'] ?? '') as String,
        notes: (json['notes'] ?? '') as String,
      );

  PurchaseReceipt copyWith({String? attachmentPath}) => PurchaseReceipt(
    receiptId: receiptId,
    receivedAt: receivedAt,
    items: items,
    invoiceAmount: invoiceAmount,
    invoiceNumber: invoiceNumber,
    freightAmount: freightAmount,
    discountAmount: discountAmount,
    attachmentPath: attachmentPath ?? this.attachmentPath,
    notes: notes,
  );
}
