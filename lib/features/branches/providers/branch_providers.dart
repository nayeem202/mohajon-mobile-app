import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/services/api_client.dart';
import '../models/branch.dart';

final currentBranchIdProvider = StateProvider<String?>((ref) {
  return ref.watch(localDatabaseProvider).settings.get('activeBranchId') as String?;
});

final branchesProvider = FutureProvider<List<Branch>>((ref) async {
  final session = ref.watch(authStateProvider).value;
  if (session == null) return const <Branch>[];
  try {
    final data = await ApiClient(ref.read(localDatabaseProvider)).getJson('/api/v1/branches');
    if (data is! List) return const <Branch>[];
    return data.whereType<Map>().map(Branch.fromJson).toList(growable: false);
  } on ApiException catch (error) {
    if (error.statusCode == 401) return const <Branch>[];
    rethrow;
  }
});

final branchServiceProvider = Provider<BranchService>((ref) => BranchService(ref));

class BranchService {
  BranchService(this._ref);
  final Ref _ref;

  Future<Branch> create({required String name, String address = '', String phone = ''}) async {
    if (name.trim().isEmpty) throw StateError('Branch name is required.');
    final json = await ApiClient(_ref.read(localDatabaseProvider)).post('/api/v1/branches', {
      'name': name.trim(),
      'address': address.trim(),
      'phone': phone.trim(),
    });
    return Branch.fromJson(json);
  }

  Future<void> select(Branch branch) async {
    await _ref.read(localDatabaseProvider).settings.put('activeBranchId', branch.branchId);
    _ref.read(currentBranchIdProvider.notifier).state = branch.branchId;
    _ref.invalidate(branchesProvider);
  }
}
