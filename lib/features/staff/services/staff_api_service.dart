import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/offline/local_database.dart';
import '../../../core/services/api_client.dart';
import '../models/staff_model.dart';
import '../models/staff_role.dart';

final staffApiServiceProvider = Provider<StaffApiService>((ref) {
  return StaffApiService(ref.read(localDatabaseProvider));
});

class StaffApiService {
  StaffApiService(this._db);

  final LocalDatabase _db;

  ApiClient get _api => ApiClient(_db);

  Future<List<StaffRole>> fetchRoles() async {
    final data = await _api.getJson('/api/v1/roles');
    if (data is! List) return const [];
    return data
        .map((e) => StaffRole.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<AppMenu>> fetchMenus() async {
    final data = await _api.getJson('/api/v1/menus');
    if (data is! List) return const [];
    return data
        .map((e) => AppMenu.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<StaffMember>> fetchStaff() async {
    final data = await _api.getJson('/api/v1/users');
    if (data is! List) return const [];
    return data
        .map((e) => StaffMember.fromApi(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<StaffMember> createStaff({
    required String name,
    required String phone,
    required String email,
    required String password,
    required String role,
    required List<String> menuCodes,
  }) async {
    final json = await _api.post('/api/v1/users', {
      'name': name,
      'phone': phone,
      'email': email,
      'password': password,
      'role': role,
      'menuCodes': menuCodes,
    });
    return StaffMember.fromApi(json);
  }

  Future<StaffMember> updateStaff({
    required String userId,
    required String name,
    required String phone,
    required String role,
    required List<String> menuCodes,
  }) async {
    final json = await _api.patch('/api/v1/users/$userId', {
      'name': name,
      'phone': phone,
      'role': role,
      'menuCodes': menuCodes,
    });
    return StaffMember.fromApi(json);
  }

  Future<void> deleteStaff(String userId) async {
    await _api.delete('/api/v1/users/$userId');
  }

  /// Menu codes granted to the currently signed-in user. The owner gets all.
  Future<List<String>> myMenuCodes() async {
    final data = await _api.getJson('/api/v1/users/me/menus');
    if (data is! List) return const [];
    return data.map((e) => e.toString()).toList();
  }
}
