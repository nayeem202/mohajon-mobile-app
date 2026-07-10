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
    shopId: (json['shopId'] ?? '') as String,
    updatedAt: dateFromJson(json['updatedAt']),
    isDeleted: json['isDeleted'] == true,
    syncStatus: SyncStatusX.parse(json['syncStatus']),
  );
}
