import 'package:hive/hive.dart';

import '../../features/notifications/models/notification_model.dart';

const notificationPushEnabledKey = 'pushEnabled';

const allNotificationTypeKeys = <String>[
  'sale', 'stock', 'expense', 'payment', 'investment', 'platform',
];

String notificationTypeLabel(NotificationType type) {
  return switch (type) {
    NotificationType.sale => 'Sales',
    NotificationType.stock => 'Stock',
    NotificationType.expense => 'Expenses',
    NotificationType.payment => 'Payments',
    NotificationType.investment => 'Investment',
    NotificationType.platform || NotificationType.system => 'Platform',
    NotificationType.summary => 'Sales',
  };
}

List<String> enabledNotificationTypeKeys() {
  final saved = Hive.box('settings').get('notifTypes', defaultValue: <String>[]);
  final selected = saved is List ? saved.cast<String>() : const <String>[];
  if (selected.isEmpty) return allNotificationTypeKeys;
  return allNotificationTypeKeys.where((key) {
    final type = NotificationType.values.firstWhere(
      (value) => value.name == key,
      orElse: () => NotificationType.system,
    );
    return selected.contains(notificationTypeLabel(type));
  }).toList();
}

bool isNotificationPushEnabled() {
  return Hive.box('settings').get(
        notificationPushEnabledKey,
        defaultValue: true,
      ) as bool;
}

Future<void> setNotificationPushEnabled(bool enabled) {
  return Hive.box('settings').put(notificationPushEnabledKey, enabled);
}

bool isNotificationTypeEnabled(NotificationType type) {
  final label = notificationTypeLabel(type);
  final saved = Hive.box('settings').get('notifTypes', defaultValue: <String>[]);
  final selected = saved is List ? saved.cast<String>() : const <String>[];
  return selected.isEmpty || selected.contains(label);
}
