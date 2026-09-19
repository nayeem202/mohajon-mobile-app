import '../utils/date_time_json.dart';
import 'syncable.dart';

class Product with Syncable {
  const Product({
    required this.productId,
    required this.nameEn,
    required this.nameBn,
    required this.barcode,
    required this.category,
    this.unit = 'pcs',
    this.imagePath,
    this.buyingPrice = 0,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.stockQty,
    required this.lowStockAlert,
    this.expiryDate,
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
  final String unit;
  final String? imagePath;
  final double buyingPrice;
  final double purchasePrice;
  final double sellingPrice;
  final int stockQty;
  final int lowStockAlert;
  final DateTime? expiryDate;
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

  bool get isExpired {
    final exp = expiryDate;
    if (exp == null) return false;
    final now = DateTime.now();
    return exp.isBefore(DateTime(now.year, now.month, now.day));
  }

  bool get isExpiringSoon {
    final exp = expiryDate;
    if (exp == null || isExpired) return false;
    final now = DateTime.now();
    final cutoff =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 7));
    return !exp.isAfter(cutoff);
  }

  Product copyWith({
    String? productId,
    String? nameEn,
    String? nameBn,
    String? barcode,
    String? category,
    String? unit,
    String? imagePath,
    double? buyingPrice,
    double? purchasePrice,
    double? sellingPrice,
    int? stockQty,
    int? lowStockAlert,
    DateTime? expiryDate,
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
      unit: unit ?? this.unit,
      imagePath: imagePath ?? this.imagePath,
      buyingPrice: buyingPrice ?? this.buyingPrice,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      stockQty: stockQty ?? this.stockQty,
      lowStockAlert: lowStockAlert ?? this.lowStockAlert,
      expiryDate: expiryDate ?? this.expiryDate,
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
    'unit': unit,
    'imagePath': imagePath,
    'buyingPrice': buyingPrice,
    'purchasePrice': purchasePrice,
    'sellingPrice': sellingPrice,
    'stockQty': stockQty,
    'lowStockAlert': lowStockAlert,
    'expiryDate': expiryDate == null ? null : dateToJson(expiryDate!),
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
    unit: (json['unit'] ?? 'pcs') as String,
    imagePath: json['imagePath'] as String?,
    buyingPrice: (json['buyingPrice'] as num? ?? 0).toDouble(),
    purchasePrice: (json['purchasePrice'] as num? ?? 0).toDouble(),
    sellingPrice: (json['sellingPrice'] as num? ?? 0).toDouble(),
    stockQty: (json['stockQty'] as num? ?? 0).toInt(),
    lowStockAlert: (json['lowStockAlert'] as num? ?? 0).toInt(),
    expiryDate: json['expiryDate'] == null
        ? null
        : dateFromJson(json['expiryDate']),
    shopId: (json['shopId'] ?? '') as String,
    updatedAt: dateFromJson(json['updatedAt']),
    isDeleted: json['isDeleted'] == true,
    syncStatus: SyncStatusX.parse(json['syncStatus']),
  );
}
