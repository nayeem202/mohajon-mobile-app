import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app/app_providers.dart';
import 'api_client.dart';

final adminServiceProvider = Provider<AdminService>((ref) {
  return AdminService(ref);
});

class AdminService {
  AdminService(this._ref);

  final Ref _ref;

  /// Deletes every piece of shop business data on the server, then clears
  /// the local Hive collections.
  Future<Map<String, dynamic>> clearAllShopData() async {
    final api = ApiClient(_ref.read(localDatabaseProvider));
    try {
      await api.delete('/api/v1/shops/me/data');
      await _ref.read(localDatabaseProvider).clearBusinessData();
      return {
        'deleted': -1,
        'failed': 0,
        'errors': <String>[],
      };
    } catch (error) {
      return {
        'deleted': 0,
        'failed': 1,
        'errors': [error.toString()],
      };
    }
  }
}
