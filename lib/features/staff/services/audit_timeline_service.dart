import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/models/audit_event.dart';
import '../../../core/services/api_client.dart';

final auditTimelineServiceProvider = Provider<AuditTimelineService>(
  (ref) => AuditTimelineService(ref),
);

class AuditTimelinePage {
  const AuditTimelinePage({
    required this.events,
    required this.hasMore,
    this.nextCursor,
  });

  final List<AuditEvent> events;
  final bool hasMore;
  final String? nextCursor;
}

/// Retrieves audit history only when the user reaches the timeline. Pages are
/// cached locally for offline viewing, while normal background sync only
/// pushes new audit rows and never downloads the full historical archive.
class AuditTimelineService {
  AuditTimelineService(this._ref);

  final Ref _ref;

  Future<AuditTimelinePage> fetchPage({String? cursor, int limit = 30}) async {
    final db = _ref.read(localDatabaseProvider);
    final response = await ApiClient(db).get(
      '/api/v1/business-guardian/timeline',
      query: {
        'limit': limit.clamp(10, 50).toString(),
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );
    final events = ((response['events'] as List?) ?? const [])
        .whereType<Map>()
        .map((json) => AuditEvent.fromJson(json))
        .toList(growable: false);

    for (final event in events) {
      await db.auditEvents.putSynced(event);
    }

    return AuditTimelinePage(
      events: events,
      hasMore: response['hasMore'] == true,
      nextCursor: response['nextCursor'] as String?,
    );
  }
}
