import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/utils/network_guard.dart';
import '../models/subscription_models.dart';
import '../services/subscription_api_service.dart';

final subscriptionRefreshProvider = StateProvider<int>((ref) => 0);

final subscriptionApiServiceProvider = Provider<SubscriptionApiService>((ref) {
  return SubscriptionApiService(ref);
});

/// Loads plans. When the device is offline the cached plan list is returned
/// right away instead of waiting for a network timeout, so the subscription
/// screen renders even without internet.
final subscriptionPlansProvider = FutureProvider<List<SubscriptionPlan>>((ref) {
  ref.watch(subscriptionRefreshProvider);
  final service = ref.watch(subscriptionApiServiceProvider);
  return _plansOrCached(service);
});

Future<List<SubscriptionPlan>> _plansOrCached(
  SubscriptionApiService service,
) async {
  final online = await isConnected();
  if (!online) {
    final cached = service.cachedPlans;
    if (cached != null && cached.isNotEmpty) return cached;
  }
  return service.fetchPlans();
}

/// Loads the current subscription status. Offline the cached status is used
/// immediately so the banner still shows instead of a blank/stepped view.
final subscriptionStatusProvider = FutureProvider<SubscriptionInfo>((ref) {
  ref.watch(subscriptionRefreshProvider);
  final service = ref.watch(subscriptionApiServiceProvider);
  return _statusOrCached(service);
});

Future<SubscriptionInfo> _statusOrCached(SubscriptionApiService service) async {
  final online = await isConnected();
  if (!online) {
    final cached = service.cachedStatus;
    if (cached != null) return cached;
  }
  return service.fetchStatus();
}