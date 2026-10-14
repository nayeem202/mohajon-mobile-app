import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/utils/network_guard.dart';

typedef SalesTrendQuery = ({DateTime from, DateTime to, String groupBy});

class SalesTrendPoint {
  const SalesTrendPoint({
    required this.periodStart,
    required this.totalSales,
    required this.saleCount,
  });

  final DateTime periodStart;
  final double totalSales;
  final int saleCount;
}

class SalesTrendResult {
  const SalesTrendResult({
    required this.totalSales,
    required this.previousPeriodSales,
    required this.changePercent,
    required this.points,
  });

  final double totalSales;
  final double previousPeriodSales;
  final double? changePercent;
  final List<SalesTrendPoint> points;
}

final salesTrendApiServiceProvider = Provider<SalesTrendApiService>((ref) {
  return SalesTrendApiService(ref);
});

final salesTrendProvider = FutureProvider.autoDispose
    .family<SalesTrendResult?, SalesTrendQuery>((ref, query) async {
      final sync = ref.watch(syncStateProvider);
      if (sync.phase == SyncPhase.syncing || sync.pendingCount > 0) return null;
      return ref.read(salesTrendApiServiceProvider).fetch(query);
    });

class SalesTrendApiService {
  SalesTrendApiService(this._ref);

  final Ref _ref;

  Future<SalesTrendResult?> fetch(SalesTrendQuery query) async {
    if (!await isConnected()) return null;
    try {
      final raw = await ApiClient(_ref.read(localDatabaseProvider)).getJson(
        '/api/v1/reports/sales-trend',
        query: {
          'from': _date(query.from),
          'to': _date(query.to),
          'groupBy': query.groupBy,
        },
      );
      if (raw is! Map) return null;
      final data = raw['data'];
      if (data is! List) return null;
      final points = <SalesTrendPoint>[];
      for (final value in data.whereType<Map>()) {
        final date = DateTime.tryParse('${value['periodStart'] ?? ''}');
        if (date == null) continue;
        points.add(
          SalesTrendPoint(
            periodStart: date,
            totalSales: (value['totalSales'] as num?)?.toDouble() ?? 0,
            saleCount: (value['saleCount'] as num?)?.toInt() ?? 0,
          ),
        );
      }
      return SalesTrendResult(
        totalSales: (raw['totalSales'] as num?)?.toDouble() ?? 0,
        previousPeriodSales:
            (raw['previousPeriodSales'] as num?)?.toDouble() ?? 0,
        changePercent: (raw['changePercent'] as num?)?.toDouble(),
        points: points,
      );
    } catch (_) {
      // Keep the chart useful when the backend is unreachable; its caller
      // falls back to the local offline-first sales cache.
      return null;
    }
  }

  String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
