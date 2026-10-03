import '../utils/date_time_json.dart';
import 'syncable.dart';

class Customer with Syncable {
  const Customer({
    required this.customerId,
    required this.name,
    required this.phone,
    this.email = '',
    this.address = '',
    this.notes = '',
    this.imagePath,
    this.totalSpent = 0.0,
    this.creditLimit = 0.0,
    this.loyaltyPoints = 0,
    this.tag = '',
    required this.shopId,
    required this.updatedAt,
    this.isDeleted = false,
    this.syncStatus = SyncStatus.pending,
  });

  final String customerId;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String notes;
  final String? imagePath;
  final double totalSpent;
  /// Zero means no credit limit configured.
  final double creditLimit;
  final int loyaltyPoints;
  final String tag;
  @override
  final String shopId;
  @override
  final DateTime updatedAt;
  final bool isDeleted;
  @override
  final SyncStatus syncStatus;

  @override
  String get id => customerId;

  Customer copyWith({
    String? customerId,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? notes,
    String? imagePath,
    double? totalSpent,
    double? creditLimit,
    int? loyaltyPoints,
    String? tag,
    String? shopId,
    DateTime? updatedAt,
    bool? isDeleted,
    SyncStatus? syncStatus,
  }) {
    return Customer(
      customerId: customerId ?? this.customerId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      imagePath: imagePath ?? this.imagePath,
      totalSpent: totalSpent ?? this.totalSpent,
      creditLimit: creditLimit ?? this.creditLimit,
      loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
      tag: tag ?? this.tag,
      shopId: shopId ?? this.shopId,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'customerId': customerId,
    'name': name,
    'phone': phone,
    'email': email,
    'address': address,
    'notes': notes,
    if (imagePath != null) 'imagePath': imagePath,
    'totalSpent': totalSpent,
    'creditLimit': creditLimit,
    'loyaltyPoints': loyaltyPoints,
    'tag': tag,
    'shopId': shopId,
    'updatedAt': dateToJson(updatedAt),
    'isDeleted': isDeleted,
    'syncStatus': syncStatus.value,
  };

  factory Customer.fromJson(Map<dynamic, dynamic> json) => Customer(
    customerId: json['customerId'] as String,
    name: (json['name'] ?? '') as String,
    phone: (json['phone'] ?? '') as String,
    email: (json['email'] ?? '') as String,
    address: (json['address'] ?? '') as String,
    notes: (json['notes'] ?? '') as String,
    imagePath: json['imagePath'] as String?,
    totalSpent: (json['totalSpent'] as num? ?? 0).toDouble(),
    creditLimit: (json['creditLimit'] as num? ?? 0).toDouble(),
    loyaltyPoints: (json['loyaltyPoints'] as num? ?? 0).toInt().clamp(0, 1 << 30),
    tag: (json['tag'] ?? '') as String,
    shopId: (json['shopId'] ?? '') as String,
    updatedAt: dateFromJson(json['updatedAt']),
    isDeleted: json['isDeleted'] == true,
    syncStatus: SyncStatusX.parse(json['syncStatus']),
  );
}
