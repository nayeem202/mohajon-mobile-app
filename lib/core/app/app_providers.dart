import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../constants/app_constants.dart';
import '../models/app_user.dart';
import '../offline/local_database.dart';
import '../services/auth_backend.dart';
import '../services/sync_service.dart';
import '../../features/auth/providers/auth_providers.dart';

final localDatabaseProvider = Provider<LocalDatabase>((ref) => LocalDatabase());

/// Emits the current auth session (custom auth service).
final authStateProvider = StreamProvider<AuthSession?>((ref) async* {
  final backend = ref.watch(authBackendProvider);
  yield await backend.currentSession();
  yield* backend.sessionChanges;
});

final shopIdProvider = Provider<String>((ref) {
  final session = ref.watch(authStateProvider).value;
  if (session == null) return AppConstants.demoShopId;
  final db = ref.watch(localDatabaseProvider);
  final activeUserId = db.settings.get('activeUserId') as String?;
  final activeShopId = db.settings.get('activeShopId') as String?;
  if (activeUserId == session.userId && activeShopId != null) {
    return activeShopId;
  }
  return 'shop_${session.userId}';
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
  final language =
      db.settings.get('languageCode', defaultValue: 'bn') as String;
  return Locale(language);
});

final themeModeProvider = StateProvider<ThemeMode>((ref) {
  final db = ref.watch(localDatabaseProvider);
  final value =
      db.settings.get('themeMode', defaultValue: ThemeMode.light.name)
          as String;
  return ThemeMode.values.firstWhere(
    (mode) => mode.name == value,
    orElse: () => ThemeMode.light,
  );
});

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref.watch(localDatabaseProvider));
});

final syncStateProvider = StateNotifierProvider<SyncController, SyncState>((
  ref,
) {
  return SyncController(
    ref.watch(syncServiceProvider),
    ref.watch(shopIdProvider),
  );
});

class SyncController extends StateNotifier<SyncState> {
  SyncController(this._syncService, this._shopId)
    : super(
        SyncState(
          phase: SyncPhase.idle,
          pendingCount: _syncService.pendingCount(shopId: _shopId),
        ),
      ) {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        syncIfOnline();
      }
    });
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
