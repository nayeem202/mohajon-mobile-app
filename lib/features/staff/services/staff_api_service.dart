import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/offline/local_database.dart';
import '../../../core/services/api_client.dart';
import '../models/staff_model.dart';
import '../models/staff_role.dart';

class StaffApiException implements Exception {
  const StaffApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

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
    try {
      final data = await _api.getJson('/api/v1/users');
      if (data is! List) throw const StaffApiException('Unexpected response');
      final staff = data
          .map((e) => StaffMember.fromApi(Map<String, dynamic>.from(e as Map)))
          .toList();
      await _db.settings.put(
        'cachedStaffList',
        staff.map((s) => s.toJson()).toList(),
      );
      return staff;
    } catch (error) {
      // A plan denial is authoritative; never disguise it by returning a
      // cached staff list. Only transient/offline failures may use the cache.
      if (error is ApiException &&
          (error.statusCode == 403 || error.code == 'SUBSCRIPTION_REQUIRED')) {
        rethrow;
      }
      // Offline: show the last known staff list so the shop can still open
      // the team screen while disconnected.
      final cached = _db.settings.get('cachedStaffList');
      if (cached is List) {
        return cached
            .map(
              (e) => StaffMember.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      }
      rethrow;
    }
  }

  Future<StaffMember> createStaff({
    required String name,
    required String phone,
    required String email,
    required String password,
    required String role,
    required List<String> menuCodes,
    String? photoUrl,
  }) async {
    final json = await _api.post('/api/v1/users', {
      'name': name,
      'phone': phone,
      'email': email,
      'password': password,
      'role': role,
      'menuCodes': menuCodes,
      if (photoUrl != null && photoUrl.isNotEmpty) 'photoUrl': photoUrl,
    });
    return StaffMember.fromApi(json);
  }

  Future<StaffMember> updateStaff({
    required String userId,
    required String name,
    required String phone,
    required String role,
    required List<String> menuCodes,
    String? photoUrl,
  }) async {
    final json = await _api.patch('/api/v1/users/$userId', {
      'name': name,
      'phone': phone,
      'role': role,
      'menuCodes': menuCodes,
      'photoUrl': ?photoUrl,
    });
    return StaffMember.fromApi(json);
  }

  /// Uploads a local image and returns the server URL for it.
  Future<String> uploadImage(File file) async {
    final json = await _api.uploadFile('/api/v1/files', file);
    final url = (json['url'] ?? '') as String;
    if (url.isEmpty) {
      throw const StaffApiException('Could not upload image');
    }
    return url;
  }

  Future<void> deleteStaff(String userId) async {
    await _api.delete('/api/v1/users/$userId');
  }

  Future<void> assignToBranch({
    required String branchId,
    required String userId,
  }) async {
    await _api.post('/api/v1/branches/$branchId/members/$userId', {});
  }

  /// Toggles a staff member's active/inactive status. An inactive staff member
  /// is blocked from signing in (the auth service rejects disabled accounts).
  Future<StaffMember> updateStaffStatus({
    required String userId,
    required bool active,
  }) async {
    final json = await _api.patch('/api/v1/users/$userId', {'active': active});
    return StaffMember.fromApi(json);
  }

  /// Menu codes granted to the currently signed-in user. The owner gets all.
  Future<List<String>> myMenuCodes() async {
    try {
      final data = await _api.getJson('/api/v1/users/me/menus');
      if (data is! List) throw const StaffApiException('Unexpected response');
      final codes = data.map((e) => e.toString()).toList();
      await _db.settings.put('cachedMenuCodes', codes);
      return codes;
    } catch (error) {
      // Offline: fall back to the last granted menus so staff do not lose
      // every navigation tile the moment the connection drops. A permission
      // change simply takes effect on the next successful fetch.
      final cached = _db.settings.get('cachedMenuCodes');
      if (cached is List) {
        return cached.map((e) => e.toString()).toList();
      }
      rethrow;
    }
  }
}
