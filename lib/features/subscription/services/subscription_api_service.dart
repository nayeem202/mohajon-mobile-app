import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/services/api_client.dart';
import '../../../core/utils/network_guard.dart';
import '../models/subscription_models.dart';

/// Data accessor for the subscription endpoints.
///
/// Plans and status are cached in Hive so the subscription screen still loads
/// when the device is offline — the user is never stuck on a spinner just
/// because the internet is down.
class SubscriptionApiService {
  SubscriptionApiService(this._ref);

  final Ref _ref;

  static const _cachedPlansKey = 'subscriptionCachedPlans';
  static const _cacheTrustDays = 3;

  ApiClient get _api => ApiClient(_ref.read(localDatabaseProvider));

  Box get _settings => _ref.read(localDatabaseProvider).settings;

  // Subscription status belongs to a shop, not to the physical device.
  // Keeping this key scoped prevents a second account on the same phone from
  // seeing the previous account's trial/subscription date.
  String get _cachedStatusKey =>
      'subscriptionCachedStatus.${_ref.read(shopIdProvider)}';

  String get _cachedStatusAtKey =>
      'subscriptionCachedStatusAt.${_ref.read(shopIdProvider)}';

  Future<List<SubscriptionPlan>> fetchPlans() async {
    try {
      final data = await _api.getJson('/api/v1/subscription/plans');
      final list = data is List ? data : const <dynamic>[];
      final plans = list
          .whereType<Map<String, dynamic>>()
          .map(SubscriptionPlan.fromJson)
          .where((p) => p.isActive)
          .toList();
      await _settings.put(
        _cachedPlansKey,
        jsonEncode([for (final p in plans) p.toJson()]),
      );
      return plans;
    } catch (_) {
      final cached = cachedPlans;
      if (cached != null && cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  /// Cached plans (best effort, no expiry — plans rarely change).
  List<SubscriptionPlan>? get cachedPlans {
    final raw = _settings.get(_cachedPlansKey) as String?;
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(SubscriptionPlan.fromJson)
          .where((p) => p.isActive)
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<SubscriptionPurchase> purchase(String planCode) async {
    final online = await isConnected();
    if (!online) {
      throw const ApiException(0, 'OFFLINE', 'No internet connection');
    }
    final data = await _api.post('/api/v1/subscription/purchase', {
      'planCode': planCode,
    });
    return SubscriptionPurchase.fromJson(data);
  }

  Future<SubscriptionConfirm> confirm(String paymentId) async {
    final online = await isConnected();
    if (!online) {
      throw const ApiException(0, 'OFFLINE', 'No internet connection');
    }
    final data = await _api.post('/api/v1/subscription/confirm', {
      'paymentId': paymentId,
    });
    return SubscriptionConfirm.fromJson(data);
  }

  Future<SubscriptionInfo> fetchStatus() async {
    try {
      final data = await _api.get('/api/v1/subscription/status');
      final info = SubscriptionInfo.fromJson(data);
      await _settings.put(_cachedStatusKey, jsonEncode(info.toJson()));
      await _settings.put(
        _cachedStatusAtKey,
        DateTime.now().toIso8601String(),
      );
      return info;
    } catch (_) {
      final cached = cachedStatus;
      if (cached != null) return cached;
      rethrow;
    }
  }

  /// Cached status, trusted for up to [_cacheTrustDays] days while offline.
  SubscriptionInfo? get cachedStatus {
    final raw = _settings.get(_cachedStatusKey) as String?;
    if (raw == null) return null;
    final cachedAt = DateTime.tryParse(
      _settings.get(_cachedStatusAtKey) as String? ?? '',
    );
    if (cachedAt == null) return null;
    if (DateTime.now().difference(cachedAt).inDays >= _cacheTrustDays) {
      return null;
    }
    try {
      return SubscriptionInfo.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }
}
