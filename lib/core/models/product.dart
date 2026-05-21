import '../utils/date_time_json.dart';
import 'syncable.dart';

class Product with Syncable {
  const Product({
    required this.productId,
    required this.nameEn,
    required this.nameBn,
    required this.barcode,
    required this.category,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.stockQty,
    required this.lowStockAlert,
    required this.shopId,
    required this.updatedAt,
    this.isDeleted = false,
    this.syncStatus = SyncStatus.pending,
  });

  final String productId;
  final String nameEn;
  final String nameBn;
  final String barcode;
  final String category;
  final double purchasePrice;
  final double sellingPrice;
  final double stockQty;
  final double lowStockAlert;
  @override
  final String shopId;
  @override
  final DateTime updatedAt;
  final bool isDeleted;
  @override
  final SyncStatus syncStatus;

  @override
  String get id => productId;

  String displayName(String languageCode) =>
      languageCode == 'bn' && nameBn.isNotEmpty ? nameBn : nameEn;

  bool get isLowStock => stockQty <= lowStockAlert;

  Product copyWith({
    String? productId,
    String? nameEn,
    String? nameBn,
    String? barcode,
    String? category,
    double? purchasePrice,
    double? sellingPrice,
    double? stockQty,
    double? lowStockAlert,
    String? shopId,
    DateTime? updatedAt,
    bool? isDeleted,
    SyncStatus? syncStatus,
  }) {
    return Product(
      productId: productId ?? this.productId,
      nameEn: nameEn ?? this.nameEn,
      nameBn: nameBn ?? this.nameBn,
      barcode: barcode ?? this.barcode,
      category: category ?? this.category,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      stockQty: stockQty ?? this.stockQty,
      lowStockAlert: lowStockAlert ?? this.lowStockAlert,
      shopId: shopId ?? this.shopId,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'productId': productId,
    'nameEn': nameEn,
    'nameBn': nameBn,
    'barcode': barcode,
    'category': category,
    'purchasePrice': purchasePrice,
    'sellingPrice': sellingPrice,
    'stockQty': stockQty,
    'lowStockAlert': lowStockAlert,
    'shopId': shopId,
    'updatedAt': dateToJson(updatedAt),
    'isDeleted': isDeleted,
    'syncStatus': syncStatus.value,
  };

  factory Product.fromJson(Map<dynamic, dynamic> json) => Product(
    productId: json['productId'] as String,
    nameEn: (json['nameEn'] ?? json['name'] ?? '') as String,
    nameBn: (json['nameBn'] ?? '') as String,
    barcode: (json['barcode'] ?? '') as String,
    category: (json['category'] ?? '') as String,
    purchasePrice: (json['purchasePrice'] as num? ?? 0).toDouble(),
    sellingPrice: (json['sellingPrice'] as num? ?? 0).toDouble(),
    stockQty: (json['stockQty'] as num? ?? 0).toDouble(),
    lowStockAlert: (json['lowStockAlert'] as num? ?? 0).toDouble(),
    shopId: (json['shopId'] ?? '') as String,
    updatedAt: dateFromJson(json['updatedAt']),
    isDeleted: json['isDeleted'] == true,
    syncStatus: SyncStatusX.parse(json['syncStatus']),
  );
}
