import '../utils/date_time_json.dart';

class ShopOwner {
  const ShopOwner({
    required this.ownerId,
    required this.name,
    required this.investmentAmount,
  });

  final String ownerId;
  final String name;
  final double investmentAmount;

  Map<String, dynamic> toJson() => {
    'ownerId': ownerId,
    'name': name,
    'investmentAmount': investmentAmount,
  };

  factory ShopOwner.fromJson(Map<dynamic, dynamic> json) => ShopOwner(
    ownerId: (json['ownerId'] ?? '') as String,
    name: (json['name'] ?? '') as String,
    investmentAmount: (json['investmentAmount'] as num? ?? 0).toDouble(),
  );
}

class ShopProfile {
  const ShopProfile({
    required this.shopId,
    required this.ownerUserId,
    required this.shopName,
    required this.location,
    required this.phoneNumber,
    required this.updatedAt,
    this.owners = const <ShopOwner>[],
    this.createdAt,
  });

  final String shopId;
  final String ownerUserId;
  final String shopName;
  final String location;
  final String phoneNumber;
  final DateTime updatedAt;
  final List<ShopOwner> owners;
  final DateTime? createdAt;

  List<ShopOwner> get effectiveOwners {
    if (owners.isNotEmpty) return owners;
    return [
      ShopOwner(
        ownerId: ownerUserId,
        name: 'Primary owner',
        investmentAmount: 0,
      ),
    ];
  }

  double get totalInvestment => effectiveOwners.fold<double>(
    0,
    (sum, owner) => sum + owner.investmentAmount,
  );

  Map<String, dynamic> toJson() => {
    'shopId': shopId,
    'ownerUserId': ownerUserId,
    'name': shopName,
    'location': location,
    'phoneNumber': phoneNumber,
    'owners': effectiveOwners.map((owner) => owner.toJson()).toList(),
    'ownerCount': effectiveOwners.length,
    'totalInvestment': totalInvestment,
    if (createdAt != null) 'createdAt': dateToJson(createdAt!),
    'updatedAt': dateToJson(updatedAt),
  };

  factory ShopProfile.fromJson(Map<dynamic, dynamic> json) {
    final ownersJson = json['owners'];
    final owners = ownersJson is List
        ? ownersJson
              .whereType<Map>()
              .map(ShopOwner.fromJson)
              .toList(growable: false)
        : const <ShopOwner>[];

    return ShopProfile(
      shopId: (json['shopId'] ?? '') as String,
      ownerUserId: (json['ownerUserId'] ?? '') as String,
      shopName: (json['name'] ?? '') as String,
      location: (json['location'] ?? '') as String,
      phoneNumber: (json['phoneNumber'] ?? '') as String,
      owners: owners,
      createdAt: json['createdAt'] == null
          ? null
          : dateFromJson(json['createdAt']),
      updatedAt: dateFromJson(json['updatedAt']),
    );
  }
}
