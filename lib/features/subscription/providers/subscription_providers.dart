import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/subscription_models.dart';
import '../services/subscription_api_service.dart';

final subscriptionRefreshProvider = StateProvider<int>((ref) => 0);

final subscriptionApiServiceProvider = Provider<SubscriptionApiService>((ref) {
  return SubscriptionApiService(ref);
});

final subscriptionPlansProvider = FutureProvider<List<SubscriptionPlan>>((ref) {
  ref.watch(subscriptionRefreshProvider);
  return ref.watch(subscriptionApiServiceProvider).fetchPlans();
});

final subscriptionStatusProvider = FutureProvider<SubscriptionInfo>((ref) {
  ref.watch(subscriptionRefreshProvider);
  return ref.watch(subscriptionApiServiceProvider).fetchStatus();
});