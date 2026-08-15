import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/staff_model.dart';
import '../models/staff_role.dart';
import '../services/staff_api_service.dart';
import '../../../core/app/app_providers.dart';

/// Roles are fetched from the Java service (configurable from the DB).
final staffRolesProvider = FutureProvider<List<StaffRole>>((ref) async {
  return ref.watch(staffApiServiceProvider).fetchRoles();
});

/// Menus are fetched from the Java service (configurable from the DB).
final staffMenusProvider = FutureProvider<List<AppMenu>>((ref) async {
  return ref.watch(staffApiServiceProvider).fetchMenus();
});

/// Staff list backed by the Java service users API.
final staffListProvider = FutureProvider<List<StaffMember>>((ref) async {
  return ref.watch(staffApiServiceProvider).fetchStaff();
});

/// Menu codes granted to the currently signed-in user. The owner sees all
/// menus; staff members only see the menus the shop owner granted them.
final myMenuCodesProvider = FutureProvider<List<String>>((ref) async {
  // Re-fetch permissions whenever the signed-in account changes. Without
  // this dependency, an owner's cached menu list could survive logout/login
  // and be reused for a staff account.
  ref.watch(authStateProvider);
  return ref.watch(staffApiServiceProvider).myMenuCodes();
});

/// Performs a staff create/update/delete against the API and refreshes the
/// staff list provider afterwards.
Future<void> staffApiAction(
  Ref ref,
  Future<void> Function(StaffApiService api) action,
) async {
  final api = ref.read(staffApiServiceProvider);
  try {
    await action(api);
  } catch (error) {
    throw StaffApiException(error.toString());
  }
  ref.invalidate(staffListProvider);
}
