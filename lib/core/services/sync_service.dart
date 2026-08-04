import 'package:connectivity_plus/connectivity_plus.dart';

import '../constants/app_constants.dart';
import '../models/syncable.dart';
import '../offline/local_collection.dart';
import '../offline/local_database.dart';
import 'api_client.dart';

enum SyncPhase { idle, syncing, offline, firebaseNotConfigured, failed }

class SyncState {
  const SyncState({
    required this.phase,
    this.message = '',
    this.pendingCount = 0,
  });

  final SyncPhase phase;
  final String message;
  final int pendingCount;
}

/// Syncs the local Hive collections with the Haalkhata business service.
class SyncService {
  SyncService(this._db) : _api = ApiClient(_db);

  final LocalDatabase _db;
  final ApiClient _api;

  static const _pullTimeout = Duration(seconds: 10);

  static const _collections = [
    ('products', 'products'),
    ('customers', 'customers'),
    ('sales', 'sales'),
    ('customerLedgerEntries', 'customerLedgerEntries'),
    ('payments', 'payments'),
    ('purchases', 'purchases'),
    ('suppliers', 'suppliers'),
    ('expenses', 'expenses'),
    ('users', 'users'),
  ];

  Future<bool> get isOnline async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (!results.any((result) => result != ConnectivityResult.none)) {
        return false;
      }
      // Confirm the business service itself is reachable.
      await _api.get(
        '/api/v1/shops/me',
        timeout: const Duration(seconds: 6),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  int pendingCount({String? shopId}) {
    if (shopId == null) {
      return _db.products.pending().length +
          _db.customers.pending().length +
          _db.sales.pending().length +
          _db.customerLedgerEntries.pending().length +
          _db.payments.pending().length +
          _db.purchases.pending().length +
          _db.suppliers.pending().length +
          _db.expenses.pending().length +
          _db.users.pending().length;
    }
    return _db.products.pendingForShop(shopId).length +
        _db.customers.pendingForShop(shopId).length +
        _db.sales.pendingForShop(shopId).length +
        _db.customerLedgerEntries.pendingForShop(shopId).length +
        _db.payments.pendingForShop(shopId).length +
        _db.purchases.pendingForShop(shopId).length +
        _db.suppliers.pendingForShop(shopId).length +
        _db.expenses.pendingForShop(shopId).length +
        _db.users.pendingForShop(shopId).length;
  }

  Future<SyncState> sync({String shopId = AppConstants.demoShopId}) async {
    if (!await isOnline) {
      return SyncState(
        phase: SyncPhase.offline,
        pendingCount: pendingCount(shopId: shopId),
      );
    }
    if (_api.accessToken == null) {
      return SyncState(
        phase: SyncPhase.firebaseNotConfigured,
        message: 'Sign in to sync with the Haalkhata service.',
        pendingCount: pendingCount(shopId: shopId),
      );
    }
    final activeUserId = _db.settings.get('activeUserId') as String?;
    if (shopId != AppConstants.demoShopId &&
        (activeUserId == null || activeUserId.isEmpty)) {
      return SyncState(
        phase: SyncPhase.failed,
        message: 'Sign in again before syncing this shop.',
        pendingCount: pendingCount(shopId: shopId),
      );
    }

    try {
      for (final (name, _) in _collections) {
        await _pushCollection(shopId, name);
      }
      for (final (name, _) in _collections) {
        await _pullCollection(name, shopId);
      }

      return SyncState(
        phase: SyncPhase.idle,
        message: 'Synced with the Haalkhata service.',
        pendingCount: pendingCount(shopId: shopId),
      );
    } catch (error) {
      return SyncState(
        phase: SyncPhase.failed,
        message: error.toString(),
        pendingCount: pendingCount(shopId: shopId),
      );
    }
  }

  LocalCollection<Syncable> _collectionFor(String name) {
    return switch (name) {
      'products' => _db.products,
      'customers' => _db.customers,
      'sales' => _db.sales,
      'customerLedgerEntries' => _db.customerLedgerEntries,
      'payments' => _db.payments,
      'purchases' => _db.purchases,
      'suppliers' => _db.suppliers,
      'expenses' => _db.expenses,
      'users' => _db.users,
      _ => throw ArgumentError('Unknown collection: $name'),
    };
  }

  Future<void> _pushCollection(String shopId, String name) async {
    final collection = _collectionFor(name);
    final items = collection.pendingForShop(shopId);
    if (items.isEmpty) return;

    final documents = <Map<String, dynamic>>[];
    for (final item in items) {
      documents.add(
        item.toJson()..['syncStatus'] = SyncStatus.synced.value,
      );
    }

    await _api.post('/api/v1/sync/push', {
      'collection': name,
      'documents': documents,
    });

    for (final item in items) {
      await collection.putSynced(item);
    }
  }

  Future<void> _pullCollection(String name, String shopId) async {
    final collection = _collectionFor(name);
    final lastPulledAt = _lastPulledAt(name, shopId);
    final response = await _api.get(
      '/api/v1/sync/pull',
      query: {
        'collection': name,
        if (lastPulledAt != null) 'after': lastPulledAt.toIso8601String(),
      },
      timeout: _pullTimeout,
    );
    final documents = (response['documents'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    for (final doc in documents) {
      if (doc['shopId'] != shopId) continue;
      await collection.mergeRemote(doc);
    }
    await _db.settings.put(
      _lastPulledKey(name, shopId),
      DateTime.now().toIso8601String(),
    );
  }

  DateTime? _lastPulledAt(String name, String shopId) {
    final value = _db.settings.get(_lastPulledKey(name, shopId));
    return value is String ? DateTime.tryParse(value) : null;
  }

  String _lastPulledKey(String name, String shopId) =>
      'firebaseLastPulledAt.$shopId.$name';
}
