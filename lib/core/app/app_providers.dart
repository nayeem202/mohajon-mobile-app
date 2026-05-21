import 'dart:async';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../constants/app_constants.dart';
import '../models/app_user.dart';
import '../offline/local_database.dart';
import '../services/sync_service.dart';

final localDatabaseProvider = Provider<LocalDatabase>((ref) => LocalDatabase());

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final shopIdProvider = Provider<String>((ref) {
  final user =
      FirebaseAuth.instance.currentUser ?? ref.watch(authStateProvider).value;
  if (user == null || user.isAnonymous) return AppConstants.demoShopId;
  final db = ref.watch(localDatabaseProvider);
  final activeUserId = db.settings.get('activeUserId') as String?;
  final activeShopId = db.settings.get('activeShopId') as String?;
  final userShopId = 'shop_${user.uid}';
  if (activeUserId == user.uid && activeShopId == userShopId) {
    return activeShopId!;
  }
  return userShopId;
});

final currentUserProvider = StateProvider<AppUser?>((ref) {
  return AppUser(
    userId: 'local-owner',
    name: 'Local Owner',
    phone: '+8801000000000',
    shopId: AppConstants.demoShopId,
    role: UserRole.owner,
    updatedAt: DateTime.now(),
  );
});

final localeProvider = StateProvider<Locale>((ref) {
  final db = ref.watch(localDatabaseProvider);
  final language = db.settings.get('languageCode', defaultValue: 'en') as String;
  return Locale(language);
});

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref.watch(localDatabaseProvider));
});

final syncStateProvider = StateNotifierProvider<SyncController, SyncState>((ref) {
  return SyncController(ref.watch(syncServiceProvider), ref.watch(shopIdProvider));
});

class SyncController extends StateNotifier<SyncState> {
  SyncController(this._syncService, this._shopId)
      : super(
          SyncState(
            phase: SyncPhase.idle,
            pendingCount: _syncService.pendingCount(shopId: _shopId),
          ),
        ) {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (results) {
        if (results.any((result) => result != ConnectivityResult.none)) {
          syncIfOnline();
        }
      },
    );
  }

  final SyncService _syncService;
  final String _shopId;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _syncing = false;

  Future<void> syncNow() async {
    if (_syncing) return;
    _syncing = true;
    state = SyncState(
      phase: SyncPhase.syncing,
      pendingCount: _syncService.pendingCount(shopId: _shopId),
    );
    try {
      state = await _syncService.sync(shopId: _shopId);
    } finally {
      _syncing = false;
    }
  }

  Future<void> syncIfOnline() async {
    if (_syncing) return;
    if (!await _syncService.isOnline) return;
    await syncNow();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
