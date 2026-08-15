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
  final String shopId;
  final String? sourceKey;
  final String? senderUserId;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.timestamp,
    this.read = false,
    required this.category,
    required this.shopId,
    this.sourceKey,
    this.senderUserId,
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
      shopId: shopId,
      sourceKey: sourceKey,
      senderUserId: senderUserId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'description': description,
    'timestamp': timestamp.toIso8601String(),
    'read': read,
    'category': category.name,
    'shopId': shopId,
    'sourceKey': sourceKey,
    'senderUserId': senderUserId,
  };

  factory AppNotification.fromJson(Map<dynamic, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      type: NotificationType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => NotificationType.system,
      ),
      title: (json['title'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      timestamp: DateTime.tryParse('${json['timestamp']}') ?? DateTime.now(),
      read: json['read'] == true,
      category: NotificationCategory.values.firstWhere(
        (value) => value.name == json['category'],
        orElse: () => NotificationCategory.shop,
      ),
      shopId: (json['shopId'] ?? '') as String,
      sourceKey: json['sourceKey'] as String?,
      senderUserId: json['senderUserId'] as String?,
    );
  }
}
