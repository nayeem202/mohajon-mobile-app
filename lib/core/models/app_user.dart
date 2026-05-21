import '../utils/date_time_json.dart';
import 'syncable.dart';

enum UserRole { owner, staff }

extension UserRoleX on UserRole {
  String get value => name.toUpperCase();

  static UserRole parse(Object? value) {
    final normalized = value.toString().toLowerCase();
    return UserRole.values.firstWhere(
      (role) => role.name == normalized,
      orElse: () => UserRole.staff,
    );
  }
}

class AppUser with Syncable {
  const AppUser({
    required this.userId,
    required this.phone,
    required this.shopId,
    required this.role,
    required this.updatedAt,
    this.name = '',
    this.syncStatus = SyncStatus.pending,
  });

  final String userId;
  final String name;
  final String phone;
  @override
  final String shopId;
  final UserRole role;
  @override
  final DateTime updatedAt;
  @override
  final SyncStatus syncStatus;

  @override
  String get id => userId;

  bool get isOwner => role == UserRole.owner;

  @override
  Map<String, dynamic> toJson() => {
    'userId': userId,
    'name': name,
    'phone': phone,
    'shopId': shopId,
    'role': role.value,
    'updatedAt': dateToJson(updatedAt),
    'syncStatus': syncStatus.value,
  };

  factory AppUser.fromJson(Map<dynamic, dynamic> json) => AppUser(
    userId: json['userId'] as String,
    name: (json['name'] ?? '') as String,
    phone: (json['phone'] ?? '') as String,
    shopId: (json['shopId'] ?? '') as String,
    role: UserRoleX.parse(json['role']),
    updatedAt: dateFromJson(json['updatedAt']),
    syncStatus: SyncStatusX.parse(json['syncStatus']),
  );
}
