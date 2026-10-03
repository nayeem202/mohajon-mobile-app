import '../utils/date_time_json.dart';
import 'syncable.dart';

class AuditEvent with Syncable {
  const AuditEvent({
    required this.eventId,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.actorId,
    required this.shopId,
    this.branchId,
    required this.createdAt,
    this.details = const {},
    this.isDeleted = false,
    this.syncStatus = SyncStatus.pending,
  });

  final String eventId;
  final String action;
  final String entityType;
  final String entityId;
  final String actorId;
  @override final String shopId;
  final String? branchId;
  final DateTime createdAt;
  final Map<String, dynamic> details;
  final bool isDeleted;
  @override final SyncStatus syncStatus;
  @override DateTime get updatedAt => createdAt;
  @override String get id => eventId;

  @override
  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'action': action,
        'entityType': entityType,
        'entityId': entityId,
        'actorId': actorId,
        'shopId': shopId,
        'branchId': branchId,
        'createdAt': dateToJson(createdAt),
        'details': details,
        'isDeleted': isDeleted,
        'syncStatus': syncStatus.value,
      };

  factory AuditEvent.fromJson(Map<dynamic, dynamic> json) => AuditEvent(
        eventId: (json['eventId'] ?? '') as String,
        action: (json['action'] ?? '') as String,
        entityType: (json['entityType'] ?? '') as String,
        entityId: (json['entityId'] ?? '') as String,
        actorId: (json['actorId'] ?? '') as String,
    shopId: (json['shopId'] ?? '') as String,
    branchId: json['branchId'] as String?,
        createdAt: dateFromJson(json['createdAt']),
        details: json['details'] is Map
            ? Map<String, dynamic>.from(json['details'] as Map)
            : const {},
        isDeleted: json['isDeleted'] == true,
        syncStatus: SyncStatusX.parse(json['syncStatus']),
      );
}
