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
      categoryFilter:
          clearCategory ? null : categoryFilter ?? this.categoryFilter,
      unreadOnly: unreadOnly ?? this.unreadOnly,
    );
  }
}

class NotificationsController extends StateNotifier<NotificationsState> {
  NotificationsController(this._db, this._shopId)
      : super(NotificationsState(items: _load(_db, _shopId))) {
    _sortAndPersist();
  }

  final LocalDatabase _db;
  final String _shopId;

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

  void delete(String id) {
    state = state.copyWith(
      items: state.items.where((n) => n.id != id).toList(),
    );
    _db.notifications.delete(id);
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
      category: category ??
          (type == NotificationType.system || type == NotificationType.platform
              ? NotificationCategory.platform
              : NotificationCategory.shop),
      shopId: _shopId,
      sourceKey: sourceKey,
    );
    state = state.copyWith(items: [item, ...state.items]);
    _persist(item);
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
  }) {
    if (!isNotificationPushEnabled()) return;
    if (!isNotificationTypeEnabled(type)) return;
    _ref.read(notificationsProvider.notifier).addNotification(
          type: type,
          title: title,
          message: message,
          category: category,
          sourceKey: sourceKey,
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
    await ApiClient(_ref.read(localDatabaseProvider)).post(
      '/api/v1/notifications/send',
      {
        'title': title,
        'body': message,
        'data': {'type': type.name},
      },
    );
  }
}
