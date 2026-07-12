import '../../../core/utils/date_time_json.dart';
import '../../../core/models/syncable.dart';

class Vendor with Syncable {
  const Vendor({
    required this.vendorId,
    required this.companyName,
    required this.contactPerson,
    required this.phone,
    this.email = '',
    this.category = '',
    this.address = '',
    this.products = '',
    this.rating = 0,
    this.totalOrders = 0,
    this.totalSpent = 0.0,
    this.pendingAmount = 0.0,
    this.lastPurchaseDate,
    this.status = 'active',
    required this.shopId,
    required this.updatedAt,
    this.createdAt,
    this.isDeleted = false,
    this.syncStatus = SyncStatus.pending,
  });

  final String vendorId;
  final String companyName;
  final String contactPerson;
  final String phone;
  final String email;
  final String category;
  final String address;
  final String products;
  final double rating;
  final int totalOrders;
  final double totalSpent;
  final double pendingAmount;
  final DateTime? lastPurchaseDate;
  final String status;
  final DateTime? createdAt;
  @override
  final String shopId;
  @override
  final DateTime updatedAt;
  final bool isDeleted;
  @override
  final SyncStatus syncStatus;

  @override
  String get id => vendorId;

  Vendor copyWith({
    String? vendorId,
    String? companyName,
    String? contactPerson,
    String? phone,
    String? email,
    String? category,
    String? address,
    String? products,
    double? rating,
    int? totalOrders,
    double? totalSpent,
    double? pendingAmount,
    DateTime? lastPurchaseDate,
    String? status,
    String? shopId,
    DateTime? updatedAt,
    DateTime? createdAt,
    bool? isDeleted,
    SyncStatus? syncStatus,
  }) {
    return Vendor(
      vendorId: vendorId ?? this.vendorId,
      companyName: companyName ?? this.companyName,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      category: category ?? this.category,
      address: address ?? this.address,
      products: products ?? this.products,
      rating: rating ?? this.rating,
      totalOrders: totalOrders ?? this.totalOrders,
      totalSpent: totalSpent ?? this.totalSpent,
      pendingAmount: pendingAmount ?? this.pendingAmount,
      lastPurchaseDate: lastPurchaseDate ?? this.lastPurchaseDate,
      status: status ?? this.status,
      shopId: shopId ?? this.shopId,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'vendorId': vendorId,
    'companyName': companyName,
    'contactPerson': contactPerson,
    'phone': phone,
    'email': email,
    'category': category,
    'address': address,
    'products': products,
    'rating': rating,
    'totalOrders': totalOrders,
    'totalSpent': totalSpent,
    'pendingAmount': pendingAmount,
    'lastPurchaseDate': lastPurchaseDate != null ? dateToJson(lastPurchaseDate!) : null,
    'status': status,
    'shopId': shopId,
    'createdAt': createdAt != null ? dateToJson(createdAt!) : null,
    'updatedAt': dateToJson(updatedAt),
    'isDeleted': isDeleted,
    'syncStatus': syncStatus.value,
  };

  factory Vendor.fromJson(Map<dynamic, dynamic> json) => Vendor(
    vendorId: json['vendorId'] as String,
    companyName: (json['companyName'] ?? '') as String,
    contactPerson: (json['contactPerson'] ?? '') as String,
    phone: (json['phone'] ?? '') as String,
    email: (json['email'] ?? '') as String,
    category: (json['category'] ?? '') as String,
    address: (json['address'] ?? '') as String,
    products: (json['products'] ?? '') as String,
    rating: (json['rating'] as num? ?? 0).toDouble(),
    totalOrders: (json['totalOrders'] as num? ?? 0).toInt(),
    totalSpent: (json['totalSpent'] as num? ?? 0).toDouble(),
    pendingAmount: (json['pendingAmount'] as num? ?? 0).toDouble(),
    lastPurchaseDate: json['lastPurchaseDate'] != null
        ? dateFromJson(json['lastPurchaseDate'])
        : null,
    status: (json['status'] ?? 'active') as String,
    shopId: (json['shopId'] ?? '') as String,
    createdAt: json['createdAt'] != null
        ? dateFromJson(json['createdAt'])
        : null,
    updatedAt: dateFromJson(json['updatedAt']),
    isDeleted: json['isDeleted'] == true,
    syncStatus: SyncStatusX.parse(json['syncStatus']),
  );
}
