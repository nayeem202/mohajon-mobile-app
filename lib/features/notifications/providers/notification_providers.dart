import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
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
    if (unreadOnly) {
      result = result.where((n) => !n.read).toList();
    }
    result.sort((a, b) {
      final aUnread = !a.read;
      final bUnread = !b.read;
      if (aUnread != bUnread) return aUnread ? -1 : 1;
      return b.timestamp.compareTo(a.timestamp);
    });
    return result;
  }

  int get unreadCount => items.where((n) => !n.read).length;

  int get shopUnreadCount =>
      items.where((n) => n.category == NotificationCategory.shop && !n.read).length;

  int get platformUnreadCount =>
      items.where((n) => n.category == NotificationCategory.platform && !n.read).length;

  NotificationsState copyWith({
    List<AppNotification>? items,
    NotificationCategory? categoryFilter,
    bool? unreadOnly,
    bool clearCategory = false,
    bool clearCategoryFilter = false,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      categoryFilter: clearCategoryFilter
          ? null
          : (clearCategory ? null : categoryFilter ?? this.categoryFilter),
      unreadOnly: unreadOnly ?? this.unreadOnly,
    );
  }
}

final _sampleData = [
  AppNotification(
    id: 'n1',
    type: NotificationType.sale,
    title: 'New Sale Completed',
    description:
        'POS sale of \u09F3\u09E8,\u09EF\u09E6\u09E6 by Karim \u2014 5 items sold from Inventory.',
    timestamp: DateTime.now().subtract(const Duration(hours: 12)),
    read: false,
    category: NotificationCategory.shop,
  ),
  AppNotification(
    id: 'n2',
    type: NotificationType.stock,
    title: 'Low Stock Alert',
    description:
        'Basmati Rice (5kg) is down to 3 units. Consider restocking soon.',
    timestamp: DateTime.now().subtract(const Duration(hours: 12)),
    read: false,
    category: NotificationCategory.shop,
  ),
  AppNotification(
    id: 'n3',
    type: NotificationType.expense,
    title: 'New Expense Recorded',
    description:
        'Electricity bill of \u09F3\u09EA,\u09E8\u09E6\u09E6 added for July 2026.',
    timestamp: DateTime.now().subtract(const Duration(days: 1)),
    read: false,
    category: NotificationCategory.shop,
  ),
  AppNotification(
    id: 'n4',
    type: NotificationType.investment,
    title: 'Investor Payout Due',
    description:
        'Monthly profit distribution is due in 3 days. Net profit pool: \u09F3\u09E8\u09E7,\u09E9\u09E6\u09E6.',
    timestamp: DateTime.now().subtract(const Duration(days: 1)),
    read: false,
    category: NotificationCategory.platform,
  ),
  AppNotification(
    id: 'n5',
    type: NotificationType.stock,
    title: 'Stock Received',
    description:
        'Vendor \u201CFresh Traders\u201D delivered 50 units of Cooking Oil (5L).',
    timestamp: DateTime.now().subtract(const Duration(days: 2)),
    read: true,
    category: NotificationCategory.shop,
  ),
  AppNotification(
    id: 'n6',
    type: NotificationType.sale,
    title: 'Daily Sales Summary',
    description:
        'July 23 \u2014 Total sales: \u09F3\u09E9\u09EE,\u09ED\u09EB\u09E6 across 24 transactions.',
    timestamp: DateTime.now().subtract(const Duration(days: 1)),
    read: true,
    category: NotificationCategory.shop,
  ),
];

class NotificationsController extends StateNotifier<NotificationsState> {
  NotificationsController() : super(NotificationsState(items: _sampleData));

  void markAsRead(String id) {
    state = state.copyWith(
      items: state.items.map((n) {
        return n.id == id ? n.copyWith(read: true) : n;
      }).toList(),
    );
  }

  void markAllAsRead() {
    state = state.copyWith(
      items: state.items.map((n) => n.copyWith(read: true)).toList(),
    );
  }

  void delete(String id) {
    state = state.copyWith(
      items: state.items.where((n) => n.id != id).toList(),
    );
  }

  void setCategoryFilter(NotificationCategory? category) {
    state = state.copyWith(
      categoryFilter: category,
      clearCategory: category == null,
    );
  }

  void addNotification({
    required NotificationType type,
    required String title,
    required String message,
  }) {
    final newNotif = AppNotification(
      id: 'n${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      title: title,
      description: message,
      timestamp: DateTime.now(),
      read: false,
      category: type == NotificationType.system
          ? NotificationCategory.platform
          : NotificationCategory.shop,
    );
    state = state.copyWith(items: [newNotif, ...state.items]);
  }

  void setUnreadOnly(bool value) {
    state = state.copyWith(unreadOnly: value);
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsController, NotificationsState>((ref) {
  return NotificationsController();
});
