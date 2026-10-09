import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../app/app_providers.dart';
import '../models/audit_event.dart';
import '../models/syncable.dart';

final auditServiceProvider = Provider<AuditService>((ref) => AuditService(ref));

class AuditService {
  AuditService(this._ref);
  final Ref _ref;

  Future<void> record({
    required String action,
    required String entityType,
    required String entityId,
    Map<String, dynamic> details = const {},
  }) async {
    final db = _ref.read(localDatabaseProvider);
    final user = _ref.read(currentUserProvider);
    final now = DateTime.now();
    final enrichedDetails = <String, dynamic>{
      ...details,
      if ((user?.name ?? '').trim().isNotEmpty) 'actorName': user!.name.trim(),
    };
    await db.auditEvents.put(
      AuditEvent(
        eventId: const Uuid().v4(),
        action: action,
        entityType: entityType,
        entityId: entityId,
        actorId: user?.userId ?? 'unknown',
        shopId: _ref.read(shopIdProvider),
        branchId:
            _ref.read(localDatabaseProvider).settings.get('activeBranchId')
                as String? ??
            '${_ref.read(shopIdProvider)}-main',
        createdAt: now,
        details: enrichedDetails,
        syncStatus: SyncStatus.pending,
      ),
    );
    unawaited(_ref.read(syncStateProvider.notifier).syncIfOnline());
  }

  List<AuditEvent> recent({int limit = 100}) {
    return _ref
        .read(localDatabaseProvider)
        .auditEvents
        .valuesForShop(_ref.read(shopIdProvider))
        .take(limit)
        .toList();
  }
}
