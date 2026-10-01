import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../config/app_config.dart';
import '../constants/app_constants.dart';
import '../models/syncable.dart';
import '../offline/local_collection.dart';
import '../offline/local_database.dart';
import 'api_client.dart';
import '../../features/purchases/models/purchase_order.dart';

enum SyncPhase { idle, syncing, offline, notSignedIn, failed }

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
    ('vendors', 'vendors'),
    ('vendorPurchases', 'vendorPurchases'),
    ('vendorPayments', 'vendorPayments'),
    ('expenses', 'expenses'),
    ('users', 'users'),
  ];

  Future<bool> get isOnline async {
    // Hard cap: a stalled DNS/connectivity call must never freeze the UI for
    // more than a few seconds on every satellite operation.
    try {
      return await _probeOnline().timeout(
        const Duration(seconds: 6),
        onTimeout: () => false,
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> _probeOnline() async {
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
          _db.vendors.pending().length +
          _db.vendorPurchases.pending().length +
          _db.vendorPayments.pending().length +
          _db.expenses.pending().length +
          _db.users.pending().length +
          _db.purchaseOrders.pending().length;
    }
    var total = _db.products.pendingForShop(shopId).length +
        _db.customers.pendingForShop(shopId).length +
        _db.sales.pendingForShop(shopId).length +
        _db.customerLedgerEntries.pendingForShop(shopId).length +
        _db.payments.pendingForShop(shopId).length +
        _db.purchases.pendingForShop(shopId).length +
        _db.suppliers.pendingForShop(shopId).length +
        _db.vendors.pendingForShop(shopId).length +
        _db.vendorPurchases.pendingForShop(shopId).length +
        _db.vendorPayments.pendingForShop(shopId).length +
        _db.expenses.pendingForShop(shopId).length +
        _db.users.pendingForShop(shopId).length +
        _db.purchaseOrders.pendingForShop(shopId).length;
    var quarantined = 0;
    for (final (name, _) in _collections) {
      final block = _db.settings.get(_quarantineKey(shopId, name));
      if (block is Map) quarantined += block.length;
    }
    // Quarantined documents stay pending in Hive but are deliberately not
    // re-sent every sync, so they must not inflate the visible pending badge.
    return total - quarantined < 0 ? 0 : total - quarantined;
  }

  static const _quarantinePrefix = 'pushQuarantine';
  static const _quarantineTriedPrefix = 'pushQuarantineTried';
  static const _quarantineRetryAfter = Duration(days: 7);

  String _quarantineKey(String shopId, String name) =>
      '$_quarantinePrefix.$shopId.$name';

  String _quarantineTriedKey(String shopId, String name) =>
      '$_quarantineTriedPrefix.$shopId.$name';

  Map<String, String> _quarantined(String shopId, String name) =>
      Map<String, String>.from(
        (_db.settings.get(_quarantineKey(shopId, name)) as Map?)
                ?.cast<String, dynamic>() ??
            const {},
      );

  Map<String, String> _quarantineTried(String shopId, String name) =>
      Map<String, String>.from(
        (_db.settings.get(_quarantineTriedKey(shopId, name)) as Map?)
                ?.cast<String, dynamic>() ??
            const {},
      );

  Future<void> _saveQuarantine(
    String shopId,
    String name,
    Map<String, String> quarantined,
    Map<String, String> tried,
  ) async {
    if (quarantined.isEmpty) {
      await _db.settings.delete(_quarantineKey(shopId, name));
    } else {
      await _db.settings.put(_quarantineKey(shopId, name), quarantined);
    }
    if (tried.isEmpty) {
      await _db.settings.delete(_quarantineTriedKey(shopId, name));
    } else {
      await _db.settings.put(_quarantineTriedKey(shopId, name), tried);
    }
  }

  /// Shared across all [SyncService] instances so startup (auth layer) and
  /// the dashboard's connectivity listener can never run two full syncs over
  /// the same Hive database at once — concurrent pulls would race the
  /// per-collection watermarks (wiping data or skipping rows).
  static Future<SyncState>? _inflightSync;

  Future<SyncState> sync({String shopId = AppConstants.demoShopId}) {
    final running = _inflightSync;
    if (running != null) return running;
    final run = _sync(shopId: shopId);
    _inflightSync = run.whenComplete(() => _inflightSync = null);
    return _inflightSync!;
  }

  Future<SyncState> _sync({String shopId = AppConstants.demoShopId}) async {
    if (!await isOnline) {
      return SyncState(
        phase: SyncPhase.offline,
        pendingCount: pendingCount(shopId: shopId),
      );
    }
    if (_api.accessToken == null) {
      return SyncState(
        phase: SyncPhase.notSignedIn,
        message: 'Sign in to sync with the Mohajon service.',
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
      // Occasional full products refresh acts as a self-heal: it repairs any
      // row that a page-boundary split could ever have skipped.
      final syncCount =
          ((_db.settings.get('syncCount') as num?) ?? 0).toInt() + 1;
      await _db.settings.put('syncCount', syncCount);
      final forceFullProducts = syncCount % 10 == 0;
      for (final (name, _) in _collections) {
        await _pullCollection(
          name,
          shopId,
          forceFull: forceFullProducts && name == 'products',
        );
      }
      // Purchase orders use a transactional endpoint because their item rows
      // are nested. Keeping this in the same sync cycle prevents device drift.
      await _syncPurchaseOrders(shopId);

      return SyncState(
        phase: SyncPhase.idle,
        message: 'Synced with the Mohajon service.',
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

  Future<void> _syncPurchaseOrders(String shopId) async {
    try {
      final remote = await _api.getJson('/api/v1/purchase-orders');
      if (remote is List) {
        for (final raw in remote.whereType<Map>()) {
          final order = PurchaseOrder.fromJson(raw).copyWith(
            shopId: shopId,
            synced: true,
            syncStatus: SyncStatus.synced,
          );
          await _db.purchaseOrders.put(order);
        }
      }
    } catch (_) {
      // A temporary endpoint failure must not discard local orders.
    }
    for (final order in _db.purchaseOrders
        .valuesForShop(shopId, includeDeleted: true)
        .where((item) => !item.synced && !item.isDeleted)) {
      try {
        await _api.post('/api/v1/purchase-orders', order.toJson());
        await _db.purchaseOrders.put(order.copyWith(
          synced: true,
          syncStatus: SyncStatus.synced,
          updatedAt: DateTime.now(),
        ));
      } catch (_) {
        // Keep the pending record for the next retry. No local data is removed.
      }
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
      'vendors' => _db.vendors,
      'vendorPurchases' => _db.vendorPurchases,
      'vendorPayments' => _db.vendorPayments,
      'expenses' => _db.expenses,
      'users' => _db.users,
      _ => throw ArgumentError('Unknown collection: $name'),
    };
  }

  Future<void> _pushCollection(String shopId, String name) async {
    final collection = _collectionFor(name);
    final items = collection.pendingForShop(shopId);
    if (items.isEmpty) return;

    // Quarantined document ids are skipped so one permanently-rejected row
    // (e.g. an old validation error) does not block the whole collection.
    // They are retried once a week and un-quarantined automatically on success
    // or when the user fixes the underlying data (edit re-marks it pending).
    final quarantined = _quarantined(shopId, name);
    final tried = _quarantineTried(shopId, name);
    final now = DateTime.now();
    final retryable = <String>{};
    quarantined.forEach((id, reason) {
      final lastTried = DateTime.tryParse(tried[id] ?? '');
      if (lastTried == null || now.difference(lastTried) >= _quarantineRetryAfter) {
        retryable.add(id);
      }
    });
    final active = items
        .where((item) =>
            !quarantined.containsKey(item.id) || retryable.contains(item.id))
        .toList();
    if (active.isEmpty) return;

    // Offline photo queue (#6): a product saved while offline keeps a local
    // file path. Now that we are online, upload it first and persist the
    // server URL locally so the product screen shows the real photo. If the
    // upload still fails, the product simply stays pending for the next sync.
    final documents = <Map<String, dynamic>>[];
    final uploadedImageIds = <String>{};
    for (final item in active) {
      final doc = item.toJson()..['syncStatus'] = SyncStatus.synced.value;
      if (name == 'products') {
        final imagePath = doc['imagePath'];
        if (imagePath is String &&
            imagePath.isNotEmpty &&
            !imagePath.startsWith('http')) {
          try {
            final json =
                await _api.uploadFile('/api/v1/files', File(imagePath));
            final url = (json['url'] ?? '').toString();
            if (url.isNotEmpty) {
              doc['imagePath'] = url.startsWith('http')
                  ? url
                  : '${AppConfig.apiBaseUrl}$url';
              uploadedImageIds.add(item.id);
            }
          } catch (_) {
            // Upload failed — cannot leave a bogus local path on the server.
            continue;
          }
        }
      }
      documents.add(doc);
    }
    if (documents.isEmpty) return;

    Map<String, dynamic> docFor(String id) => documents.firstWhere(
      (doc) => doc['id'] == id,
      orElse: () => active
          .firstWhere((item) => item.id == id, orElse: () => active.first)
          .toJson(),
    );

    try {
      await _api.post('/api/v1/sync/push', {
        'collection': name,
        'documents': documents,
      });
      for (final item in active) {
        if (uploadedImageIds.contains(item.id)) {
          await collection.putRemoteJson(item.shopId, item.id, docFor(item.id));
        } else {
          await collection.putSynced(item);
        }
        quarantined.remove(item.id);
        tried.remove(item.id);
      }
    } on ApiException {
      // The whole batch was rejected — isolate the offending document(s) by
      // pushing each one individually so the rest can still get through.
      for (final item in active) {
        final one = [docFor(item.id)];
        try {
          await _api.post('/api/v1/sync/push', {
            'collection': name,
            'documents': one,
          });
          if (uploadedImageIds.contains(item.id)) {
            await collection.putRemoteJson(item.shopId, item.id, one.first);
          } else {
            await collection.putSynced(item);
          }
          quarantined.remove(item.id);
          tried.remove(item.id);
        } on ApiException catch (error) {
          if (error.statusCode >= 400 && error.statusCode < 500) {
            // Permanent server rejection — quarantine instead of bouncing off
            // it on every future sync.
            quarantined[item.id] = '${error.code}: ${error.message}';
          }
          tried[item.id] = now.toIso8601String();
        } catch (_) {
          // Transient (network/timeout) — leave pending, retry next sync.
          tried[item.id] = now.toIso8601String();
        }
      }
    } catch (_) {
      // Transient for the whole batch — keep everything pending.
      return;
    }

    await _saveQuarantine(shopId, name, quarantined, tried);
  }

  Future<void> _pullCollection(
    String name,
    String shopId, {
    bool forceFull = false,
  }) async {
    final collection = _collectionFor(name);
    var after = forceFull ? null : _lastPulledAt(name, shopId);
    // The server captures `serverNow` before each query and returns it with
    // every page. Using it as the watermark (instead of the device clock)
    // guarantees no row is ever skipped because of client-server clock skew.
    DateTime? serverNow;

    // Chunked delta pull: the server caps each page when `limit` is sent and
    // reports `hasMore`, so a huge backlog never arrives as one giant
    // response. `after` advances to the newest updatedAt seen in each page;
    // if a page makes no progress we nudge it forward to guarantee the loop
    // always terminates.
    while (true) {
      final response = await _api.get(
        '/api/v1/sync/pull',
        query: {
          'collection': name,
          'limit': '500',
          if (after != null) 'after': after.toIso8601String(),
        },
        timeout: _pullTimeout,
      );
      final serverValue = DateTime.tryParse('${response['serverNow']}');
      if (serverValue != null && (serverNow == null || serverValue.isAfter(serverNow))) {
        serverNow = serverValue;
      }
      final documents = (response['documents'] as List?)
          ?.cast<Map<String, dynamic>>() ??
      const <Map<String, dynamic>>[];
      var newest = after;
      for (final doc in documents) {
        if (doc['shopId'] != shopId) continue;
        await collection.mergeRemote(doc);
        final updated = DateTime.tryParse('${doc['updatedAt']}');
        if (updated != null && (newest == null || updated.isAfter(newest))) {
          newest = updated;
        }
      }
      if (response['hasMore'] != true) {
        after = serverNow ?? DateTime.now();
        break;
      }
      if (newest != null && (after == null || newest.isAfter(after))) {
        after = newest;
      } else {
        after = (after ?? DateTime.now()).add(const Duration(milliseconds: 1));
      }
    }

    await _db.settings.put(
      _lastPulledKey(name, shopId),
      after.toIso8601String(),
    );
  }

  DateTime? _lastPulledAt(String name, String shopId) {
    final value = _db.settings.get(_lastPulledKey(name, shopId));
    return value is String ? DateTime.tryParse(value) : null;
  }

  String _lastPulledKey(String name, String shopId) =>
      'lastPulledAt.$shopId.$name';
}
