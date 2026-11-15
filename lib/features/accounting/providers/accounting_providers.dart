import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/app/app_providers.dart';
import '../../../core/models/app_user.dart';
import '../../../core/services/api_client.dart';
import '../../../core/utils/network_guard.dart';
import '../../branches/providers/branch_providers.dart';
import '../data/accounting_client.dart';
import '../domain/local_income_statement.dart';

final accountingRefreshProvider = StateProvider<int>((ref) => 0);
final accountingClientProvider = Provider<AccountingClient>((ref) {
  final db = ref.watch(localDatabaseProvider);
  final shop = ref.watch(shopIdProvider);
  final branch = ref.watch(currentBranchIdProvider) ?? '$shop-main';
  final owner = ref.watch(currentUserProvider);
  if (owner?.role != UserRole.owner) {
    throw const ApiException(403, 'FORBIDDEN', 'Owner access required.');
  }
  final api = ApiClient(db);
  return AccountingClient(
    settings: db.settings,
    shopId: shop,
    branchId: branch,
    userId: db.settings.get('activeUserId') as String? ?? owner!.userId,
    get: (path, query) => api.get(path, query: query),
    post: (path, body) => api.post(path, body),
    online: isConnected,
  );
});
final accountingStateProvider = FutureProvider<Map<String, dynamic>>((ref) {
  ref.watch(accountingRefreshProvider);
  return ref.watch(accountingClientProvider).state();
});
final accountingPendingProvider = Provider<List<Map<String, dynamic>>>((ref) {
  ref.watch(accountingRefreshProvider);
  final client = ref.watch(accountingClientProvider);
  return client.outbox.pending(client.shopId, client.branchId, client.userId);
});
final accountingJournalProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ({String from, String to})>((ref, query) {
      ref.watch(accountingRefreshProvider);
      return ref.watch(accountingClientProvider).journal(query.from, query.to);
    });
typedef AccountingQuery = ({String kind, String from, String to});
final accountingReportProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, AccountingQuery>((ref, query) async {
      ref.watch(accountingRefreshProvider);
      final client = ref.watch(accountingClientProvider);
      try {
        final report = await client.report(query.kind, query.from, query.to);
        if (report['configured'] == true || query.kind != 'income') {
          return report;
        }
      } on ApiException catch (error) {
        if (query.kind != 'income' ||
            error.statusCode == 401 ||
            error.statusCode == 403) {
          rethrow;
        }
        // Retain the existing local P&L functionality before server setup/deploy.
      }
      final db = ref.read(localDatabaseProvider);
      return localIncomeStatement(
        sales: db.sales.valuesForShop(client.shopId),
        returns: db.saleReturns.valuesForShop(client.shopId),
        expenses: db.expenses.valuesForShop(client.shopId),
        shopId: client.shopId,
        branchId: client.branchId,
        from: DateTime.parse(query.from),
        to: DateTime.parse(query.to),
      );
    });
