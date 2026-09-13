import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/services/api_client.dart';
import '../models/subscription_models.dart';

class SubscriptionApiService {
  SubscriptionApiService(this._ref);

  final Ref _ref;

  ApiClient get _api => ApiClient(_ref.read(localDatabaseProvider));

  Future<List<SubscriptionPlan>> fetchPlans() async {
    final data = await _api.getJson('/api/v1/subscription/plans');
    final list = data is List ? data : const <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(SubscriptionPlan.fromJson)
        .where((p) => p.isActive)
        .toList();
  }

  Future<SubscriptionPurchase> purchase(String planCode) async {
    final data = await _api.post('/api/v1/subscription/purchase', {
      'planCode': planCode,
    });
    return SubscriptionPurchase.fromJson(data);
  }

  Future<SubscriptionConfirm> confirm(String paymentId) async {
    final data = await _api.post('/api/v1/subscription/confirm', {
      'paymentId': paymentId,
    });
    return SubscriptionConfirm.fromJson(data);
  }

  Future<SubscriptionInfo> fetchStatus() async {
    final data = await _api.get('/api/v1/subscription/status');
    return SubscriptionInfo.fromJson(data);
  }
}