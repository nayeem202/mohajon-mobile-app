import '../utils/date_time_json.dart';

class ShopProfile {
  const ShopProfile({
    required this.shopId,
    required this.ownerUserId,
    required this.shopName,
    required this.location,
    required this.phoneNumber,
    required this.updatedAt,
    this.createdAt,
  });

  final String shopId;
  final String ownerUserId;
  final String shopName;
  final String location;
  final String phoneNumber;
  final DateTime updatedAt;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
    'shopId': shopId,
    'ownerUserId': ownerUserId,
    'name': shopName,
    'location': location,
    'phoneNumber': phoneNumber,
    if (createdAt != null) 'createdAt': dateToJson(createdAt!),
    'updatedAt': dateToJson(updatedAt),
  };

  factory ShopProfile.fromJson(Map<dynamic, dynamic> json) => ShopProfile(
    shopId: (json['shopId'] ?? '') as String,
    ownerUserId: (json['ownerUserId'] ?? '') as String,
    shopName: (json['name'] ?? '') as String,
    location: (json['location'] ?? '') as String,
    phoneNumber: (json['phoneNumber'] ?? '') as String,
    createdAt: json['createdAt'] == null ? null : dateFromJson(json['createdAt']),
    updatedAt: dateFromJson(json['updatedAt']),
  );
}
