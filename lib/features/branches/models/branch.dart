class Branch {
  const Branch({
    required this.branchId,
    required this.shopId,
    required this.name,
    this.address = '',
    this.phone = '',
    this.isActive = true,
    this.isDefault = false,
  });

  final String branchId;
  final String shopId;
  final String name;
  final String address;
  final String phone;
  final bool isActive;
  final bool isDefault;

  factory Branch.fromJson(Map<dynamic, dynamic> json) => Branch(
        branchId: (json['branchId'] ?? '') as String,
        shopId: (json['shopId'] ?? '') as String,
        name: (json['name'] ?? '') as String,
        address: (json['address'] ?? '') as String,
        phone: (json['phone'] ?? '') as String,
        isActive: json['isActive'] != false,
        isDefault: json['isDefault'] == true,
      );
}
