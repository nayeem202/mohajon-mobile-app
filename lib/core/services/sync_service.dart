import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../app/app_bootstrap.dart';
import '../constants/app_constants.dart';
import '../models/syncable.dart';
import '../offline/local_collection.dart';
import '../offline/local_database.dart';
import 'firestore_paths.dart';

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

class SyncService {
  SyncService(this._db, {FirebaseFirestore? firestore})
    : _firestore =
          firestore ??
          (AppBootstrap.firebaseReady ? FirebaseFirestore.instance : null);

  final LocalDatabase _db;
  final FirebaseFirestore? _firestore;

  Future<bool> get isOnline async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((result) => result != ConnectivityResult.none);
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
          _db.users.pending().length;
    }
    return _db.products.pendingForShop(shopId).length +
        _db.customers.pendingForShop(shopId).length +
        _db.sales.pendingForShop(shopId).length +
        _db.customerLedgerEntries.pendingForShop(shopId).length +
        _db.payments.pendingForShop(shopId).length +
        _db.purchases.pendingForShop(shopId).length +
        _db.suppliers.pendingForShop(shopId).length +
        _db.users.pendingForShop(shopId).length;
  }

  Future<SyncState> sync({String shopId = AppConstants.demoShopId}) async {
    if (!await isOnline) {
      return SyncState(
        phase: SyncPhase.offline,
        pendingCount: pendingCount(shopId: shopId),
      );
    }
    if (_firestore == null) {
      return SyncState(
        phase: SyncPhase.firebaseNotConfigured,
        message: 'Firebase is not configured; local mode is active.',
        pendingCount: pendingCount(shopId: shopId),
      );
    }
    final user = FirebaseAuth.instance.currentUser;
    if (shopId != AppConstants.demoShopId &&
        (user == null || user.isAnonymous)) {
      return SyncState(
        phase: SyncPhase.failed,
        message: 'Sign in again before syncing this shop.',
        pendingCount: pendingCount(shopId: shopId),
      );
    }

    try {
      final paths = FirestorePaths(_firestore, shopId);
      await _pushCollection(shopId, _db.products, paths.collection('products'));
      await _pushCollection(
        shopId,
        _db.customers,
        paths.collection('customers'),
      );
      await _pushCollection(shopId, _db.sales, paths.collection('sales'));
      await _pushCollection(
        shopId,
        _db.customerLedgerEntries,
        paths.collection('customerLedgerEntries'),
      );
      await _pushCollection(
        shopId,
        _db.payments,
        paths.collection('payments'),
      );
      await _pushCollection(
        shopId,
        _db.purchases,
        paths.collection('purchases'),
      );
      await _pushCollection(
        shopId,
        _db.suppliers,
        paths.collection('suppliers'),
      );
      await _pushCollection(shopId, _db.users, paths.collection('users'));

      await _pullCollection(
        'products',
        shopId,
        _db.products,
        paths.collection('products'),
      );
      await _pullCollection(
        'customers',
        shopId,
        _db.customers,
        paths.collection('customers'),
      );
      await _pullCollection('sales', shopId, _db.sales, paths.collection('sales'));
      await _pullCollection(
        'customerLedgerEntries',
        shopId,
        _db.customerLedgerEntries,
        paths.collection('customerLedgerEntries'),
      );
      await _pullCollection(
        'payments',
        shopId,
        _db.payments,
        paths.collection('payments'),
      );
      await _pullCollection(
        'purchases',
        shopId,
        _db.purchases,
        paths.collection('purchases'),
      );
      await _pullCollection(
        'suppliers',
        shopId,
        _db.suppliers,
        paths.collection('suppliers'),
      );
      await _pullCollection('users', shopId, _db.users, paths.collection('users'));

      return SyncState(
        phase: SyncPhase.idle,
        message: 'Synced with Firebase.',
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

  Future<void> _pushCollection<T extends Syncable>(
    String shopId,
    LocalCollection<T> collection,
    CollectionReference<Map<String, dynamic>> remote,
  ) async {
    for (final item in collection.pending()) {
      if (item.shopId != shopId) continue;
      final remoteJson = item.toJson()
        ..['syncStatus'] = SyncStatus.synced.value;
      await remote.doc(item.id).set(remoteJson, SetOptions(merge: true));
      await collection.putSynced(item);
    }
  }

  Future<void> _pullCollection<T extends Syncable>(
    String name,
    String shopId,
    LocalCollection<T> collection,
    CollectionReference<Map<String, dynamic>> remote,
  ) async {
    final lastPulledAt = _lastPulledAt(name, shopId);
    final query = lastPulledAt == null
        ? remote.orderBy('updatedAt')
        : remote
              .where(
                'updatedAt',
                isGreaterThan: lastPulledAt.toUtc().toIso8601String(),
              )
              .orderBy('updatedAt');
    final snapshot = await query.get();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['shopId'] != shopId) continue;
      await collection.mergeRemote(data);
    }
    await _db.settings.put(
      _lastPulledKey(name, shopId),
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  DateTime? _lastPulledAt(String name, String shopId) {
    final value = _db.settings.get(_lastPulledKey(name, shopId));
    return value is String ? DateTime.tryParse(value) : null;
  }

  String _lastPulledKey(String name, String shopId) =>
      'firebaseLastPulledAt.$shopId.$name';
}
