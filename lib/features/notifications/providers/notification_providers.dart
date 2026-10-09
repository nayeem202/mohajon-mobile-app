import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/offline/local_database.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/notification_preferences.dart';
import '../models/notification_model.dart';

class NotificationsState {
  final List<AppNotification> items;
  final NotificationCategory? categoryFilter;
  final bool unreadOnly;

  const NotificationsState({
    required this.items,
    this.categoryFilter,
    this.unreadOnly = false,
  });

  List<AppNotification> get filtered {
    var result = items.toList();
    if (categoryFilter != null) {
      result = result.where((n) => n.category == categoryFilter).toList();
    }
    if (unreadOnly) result = result.where((n) => !n.read).toList();
    result.sort((a, b) {
      if (a.read != b.read) return a.read ? 1 : -1;
      return b.timestamp.compareTo(a.timestamp);
    });
    return result;
  }

  int get unreadCount => items.where((n) => !n.read).length;

  int get shopUnreadCount => items
      .where((n) => n.category == NotificationCategory.shop && !n.read)
      .length;

  int get platformUnreadCount => items
      .where((n) => n.category == NotificationCategory.platform && !n.read)
      .length;

  NotificationsState copyWith({
    List<AppNotification>? items,
    NotificationCategory? categoryFilter,
    bool? unreadOnly,
    bool clearCategory = false,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      categoryFilter: clearCategory
          ? null
          : categoryFilter ?? this.categoryFilter,
      unreadOnly: unreadOnly ?? this.unreadOnly,
    );
  }
}

class NotificationsController extends StateNotifier<NotificationsState> {
  NotificationsController(this._db, this._shopId)
    : super(NotificationsState(items: _load(_db, _shopId))) {
    _sortAndPersist();
    unawaited(_loadSharedHistory());
    _historyRefreshTimer = Timer.periodic(
      // Notifications are near-real-time via FCM; 30s polling is a cheap
      // reconciliation net that does not hammer the service per device.
      const Duration(seconds: 30),
      (_) => unawaited(_loadSharedHistory()),
    );
  }

  final LocalDatabase _db;
  final String _shopId;
  Timer? _historyRefreshTimer;

  static List<AppNotification> _load(LocalDatabase db, String shopId) {
    return db.notifications.values
        .map(AppNotification.fromJson)
        .where((item) => item.shopId == shopId)
        .toList();
  }

  void _sortAndPersist() {
    final items = [...state.items]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    state = state.copyWith(items: items);
  }

  Future<void> _persist(AppNotification item) =>
      _db.notifications.put(item.id, item.toJson());

  Future<void> _loadSharedHistory() async {
    try {
      final data = await ApiClient(
        _db,
      ).getJson('/api/v1/notifications/history');
      if (data is! List) return;
      final languageCode = _db.settings.get('languageCode', defaultValue: 'bn');
      final remote = data.whereType<Map>().map((item) {
        final localized = Map<dynamic, dynamic>.from(item);
        if (languageCode == 'bn') {
          final titleBn = localized['titleBn']?.toString().trim();
          final bodyBn = localized['descriptionBn']?.toString().trim();
          if (titleBn != null && titleBn.isNotEmpty) {
            localized['title'] = titleBn;
          }
          if (bodyBn != null && bodyBn.isNotEmpty) {
            localized['description'] = bodyBn;
          }
        }
        return AppNotification.fromJson(localized);
      }).toList();
      final existingBySource = <String, AppNotification>{
        for (final item in state.items)
          if (item.sourceKey != null) item.sourceKey!: item,
      };
      final merged = [...state.items];
      for (final item in remote) {
        final old = item.sourceKey == null
            ? null
            : existingBySource[item.sourceKey];
        if (old == null) {
          merged.add(item);
          await _persist(item);
        }
      }
      state = state.copyWith(items: merged);
      _sortAndPersist();
    } catch (_) {
      // Local notifications remain available when the history endpoint is offline.
    }
  }

  void markAsRead(String id) {
    final item = state.items.where((n) => n.id == id).firstOrNull;
    if (item == null || item.read) return;
    final updated = item.copyWith(read: true);
    state = state.copyWith(
      items: state.items.map((n) => n.id == id ? updated : n).toList(),
    );
    _persist(updated);
  }

  void markAllAsRead() {
    final updated = state.items.map((n) => n.copyWith(read: true)).toList();
    state = state.copyWith(items: updated);
    for (final item in updated) {
      _persist(item);
    }
  }

  Future<void> delete(String id, {bool everyone = false}) async {
    final item = state.items.where((n) => n.id == id).firstOrNull;
    final sourceKey = item?.sourceKey;
    final serverId = sourceKey != null && sourceKey.startsWith('server:')
        ? sourceKey.substring('server:'.length)
        : null;
    final platformId = sourceKey != null && sourceKey.startsWith('platform:')
        ? sourceKey.substring('platform:'.length)
        : null;
    if (everyone && serverId != null) {
      await ApiClient(
        _db,
      ).delete('/api/v1/notifications/history/$serverId/everyone');
    }
    state = state.copyWith(
      items: state.items.where((n) => n.id != id).toList(),
    );
    _db.notifications.delete(id);
    if (platformId != null) {
      try {
        await ApiClient(
          _db,
        ).delete('/api/v1/notifications/history/platform/$platformId');
      } catch (_) {
        // Local deletion remains applied; the next history refresh will retry
        // the server-backed delete when a connection is available.
      }
      return;
    }
    if (serverId == null || everyone) return;
    try {
      await ApiClient(_db).delete('/api/v1/notifications/history/$serverId');
    } catch (_) {
      // The local delete remains applied; a later sync can restore it if the
      // server deletion failed.
    }
  }

  void setCategoryFilter(NotificationCategory? category) {
    state = state.copyWith(
      categoryFilter: category,
      clearCategory: category == null,
    );
  }

  void setUnreadOnly(bool value) {
    state = state.copyWith(unreadOnly: value);
  }

  void addNotification({
    required NotificationType type,
    required String title,
    required String message,
    NotificationCategory? category,
    String? sourceKey,
    String? senderUserId,
  }) {
    if (sourceKey != null &&
        state.items.any((item) => item.sourceKey == sourceKey)) {
      return;
    }
    final now = DateTime.now();
    final item = AppNotification(
      id: 'n-${now.microsecondsSinceEpoch}',
      type: type,
      title: title,
      description: message,
      timestamp: now,
      category:
          category ??
          (type == NotificationType.system || type == NotificationType.platform
              ? NotificationCategory.platform
              : NotificationCategory.shop),
      shopId: _shopId,
      sourceKey: sourceKey,
      senderUserId: senderUserId,
    );
    state = state.copyWith(items: [item, ...state.items]);
    _persist(item);
  }

  @override
  void dispose() {
    _historyRefreshTimer?.cancel();
    super.dispose();
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsController, NotificationsState>((ref) {
      return NotificationsController(
        ref.watch(localDatabaseProvider),
        ref.watch(shopIdProvider),
      );
    });

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref);
});

class NotificationService {
  NotificationService(this._ref);

  final Ref _ref;

  void add({
    required NotificationType type,
    required String title,
    required String message,
    NotificationCategory? category,
    String? sourceKey,
    String? senderUserId,
  }) {
    if (!isNotificationPushEnabled()) return;
    if (!isNotificationTypeEnabled(type)) return;
    _ref
        .read(notificationsProvider.notifier)
        .addNotification(
          type: type,
          title: title,
          message: message,
          category: category,
          sourceKey: sourceKey,
          senderUserId:
              senderUserId ?? _ref.read(authStateProvider).value?.userId,
        );
  }

  Future<void> sendPush({
    required NotificationType type,
    required String title,
    required String message,
  }) async {
    if (!isNotificationPushEnabled()) {
      throw StateError('Push notifications are disabled in Settings.');
    }
    final response = await ApiClient(_ref.read(localDatabaseProvider)).post(
      '/api/v1/notifications/send',
      {
        'title': title,
        'body': message,
        // System notifications are stored/filtered under the Platform type.
        'data': {
          'type': type == NotificationType.system ? 'platform' : type.name,
        },
      },
    );
    final notificationId = response['notificationId']?.toString();
    final storedType = type == NotificationType.system
        ? NotificationType.platform
        : type;
    try {
      _ref
          .read(notificationServiceProvider)
          .add(
            type: storedType,
            category: storedType == NotificationType.platform
                ? NotificationCategory.platform
                : NotificationCategory.shop,
            title: title,
            message: message,
            sourceKey: notificationId == null ? null : 'server:$notificationId',
          );
    } catch (error, stackTrace) {
      // The server has already accepted the notification. Do not report a
      // successful remote send as a failed send if local Hive/UI persistence
      // has a separate problem.
      debugPrint('Local notification display failed after remote send: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
