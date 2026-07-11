class Profile {
  const Profile({
    required this.userId,
    required this.storeName,
    required this.ownerName,
    required this.phone,
    required this.email,
    required this.address,
    this.imagePath,
  });

  final String userId;
  final String storeName;
  final String ownerName;
  final String phone;
  final String email;
  final String address;
  final String? imagePath;

  Profile copyWith({
    String? userId,
    String? storeName,
    String? ownerName,
    String? phone,
    String? email,
    String? address,
    Object? imagePath = const Object(),
  }) {
    return Profile(
      userId: userId ?? this.userId,
      storeName: storeName ?? this.storeName,
      ownerName: ownerName ?? this.ownerName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      imagePath: identical(imagePath, const Object()) ? this.imagePath : imagePath as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'storeName': storeName,
    'ownerName': ownerName,
    'phone': phone,
    'email': email,
    'address': address,
    if (imagePath != null) 'imagePath': imagePath,
  };

  factory Profile.fromJson(Map<dynamic, dynamic> json) => Profile(
    userId: (json['userId'] ?? '') as String,
    storeName: (json['storeName'] ?? '') as String,
    ownerName: (json['ownerName'] ?? '') as String,
    phone: (json['phone'] ?? '') as String,
    email: (json['email'] ?? '') as String,
    address: (json['address'] ?? '') as String,
    imagePath: json['imagePath'] as String?,
  );
}
