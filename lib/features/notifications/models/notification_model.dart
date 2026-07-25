enum NotificationType { sale, stock, expense, investment, platform, summary, system, payment }

enum NotificationCategory { shop, platform }

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String description;
  final DateTime timestamp;
  final bool read;
  final NotificationCategory category;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.timestamp,
    this.read = false,
    required this.category,
  });

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      description: description,
      timestamp: timestamp,
      read: read ?? this.read,
      category: category,
    );
  }
}
