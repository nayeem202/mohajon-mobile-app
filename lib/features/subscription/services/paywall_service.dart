import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hive/hive.dart';

import '../../../core/constants/app_constants.dart';
import '../models/subscription_models.dart';
import '../providers/subscription_providers.dart';
import 'subscription_api_service.dart';

/// Paywall enforcement for the freemium model:
/// - During the free trial and an active subscription: full access.
/// - After the trial/subscription expires: read-only mode — the shop owner can
///   still view every report and all history, but new entries are blocked
///   until they subscribe.
/// - Offline friendly: the last known status is cached in Hive. If the app is
///   offline and has no cached status, writes are allowed (never lock a shop
///   out of its own data just because the internet is down).
class PaywallService {
  PaywallService(this._ref);

  final Ref _ref;

  static const _cachedStatusKey = 'paywallCachedSubscriptionStatus';
  static const _cachedAtKey = 'paywallCachedStatusAt';
  static const _gateDisabledKey = 'paywallGateDisabled';

  /// Cache is trusted for at most this long while offline.
  static const _cacheTrustDays = 3;

  SubscriptionApiService get _api =>
      _ref.read(subscriptionApiServiceProvider);

  Box get _settings => Hive.box(HiveBoxes.settings);

  /// Whether the paywall gate is enabled at all (demo/offline builds may
  /// disable it). Defaults to enabled.
  bool get gateEnabled =>
      _settings.get(_gateDisabledKey, defaultValue: false) as bool == false;

  Future<void> setGateEnabled(bool enabled) async {
    await _settings.put(_gateDisabledKey, !enabled);
  }

  /// Fetches the latest status from the server and caches it.
  Future<SubscriptionInfo> refresh() async {
    final info = await _api.fetchStatus();
    await _cache(info);
    return info;
  }

  Future<void> _cache(SubscriptionInfo info) async {
    _settings
      ..put(_cachedStatusKey, jsonEncode(_infoToJson(info)))
      ..put(_cachedAtKey, DateTime.now().toIso8601String());
  }

  /// Cached status, if present and fresh enough.
  SubscriptionInfo? get cachedStatus {
    final raw = _settings.get(_cachedStatusKey) as String?;
    if (raw == null) return null;
    final cachedAt = DateTime.tryParse(
      _settings.get(_cachedAtKey) as String? ?? '',
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

  Map<String, dynamic> _infoToJson(SubscriptionInfo info) {
    return {
      'hasActive': info.hasActive,
      'isTrial': info.isTrial,
      'daysRemaining': info.daysRemaining,
      'subscription': {
        'subscriptionId': info.subscriptionId,
        'status': info.status,
        'planCode': info.planCode,
        'startDate': info.startDate,
        'endDate': info.endDate,
        'plan': {
          'name': info.planName,
          'price': info.amountBdt?.toStringAsFixed(2),
        },
      },
    };
  }

  /// The verdict used by the UI gate.
  ///
  /// [online] tells the service whether the device currently has internet.
  /// - Online: server status wins (falls back to cache on error).
  /// - Offline: cached status decides; no cache → writes allowed.
  Future<PaywallVerdict> verdict({required bool online}) async {
    if (!gateEnabled) return PaywallVerdict.fullAccess;
    if (!online) {
      final cached = cachedStatus;
      if (cached == null) return PaywallVerdict.fullAccess;
      return _verdictFor(cached);
    }
    try {
      final fresh = await refresh();
      return _verdictFor(fresh);
    } catch (_) {
      final cached = cachedStatus;
      if (cached == null) return PaywallVerdict.fullAccess;
      return _verdictFor(cached);
    }
  }

  PaywallVerdict _verdictFor(SubscriptionInfo info) {
    if (info.hasActive) return PaywallVerdict.fullAccess;
    return PaywallVerdict.readOnly;
  }
}

enum PaywallVerdict { fullAccess, readOnly }

/// Live paywall state, refreshed whenever the app starts, resumes or the
/// connectivity changes.
final paywallStateProvider =
    StateNotifierProvider<PaywallController, PaywallVerdict>((ref) {
  return PaywallController(ref);
});

class PaywallController extends StateNotifier<PaywallVerdict> {
  PaywallController(this._ref) : super(PaywallVerdict.fullAccess) {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      final online = results.any((r) => r != ConnectivityResult.none);
      refresh(online: online);
    });
  }

  final Ref _ref;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  PaywallService get _service => _ref.read(paywallServiceProvider);

  /// Recomputes the verdict. Called on app start, resume and connectivity
  /// changes. Errors never throw — worst case the gate stays permissive.
  Future<void> refresh({required bool online}) async {
    try {
      final result = await _service.verdict(online: online);
      if (mounted) state = result;
    } catch (_) {
      // Keep the previous state.
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}

final paywallServiceProvider = Provider<PaywallService>((ref) {
  return PaywallService(ref);
});

/// Convenience: is the shop currently in read-only mode?
final isReadOnlyProvider = Provider<bool>((ref) {
  return ref.watch(paywallStateProvider) == PaywallVerdict.readOnly;
});
