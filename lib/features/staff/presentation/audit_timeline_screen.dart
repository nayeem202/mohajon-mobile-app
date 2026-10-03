import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/audit_event.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../branches/providers/branch_providers.dart';

class AuditTimelineScreen extends ConsumerWidget {
  const AuditTimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final db = ref.read(localDatabaseProvider);
    final shopId = ref.watch(shopIdProvider);
    final branchId = ref.watch(currentBranchIdProvider) ?? '$shopId-main';
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('auditTimeline')),
        actions: const [SyncStatusIndicator(), NotificationBell()],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: MohajonWarm.pageGradient),
        child: StreamBuilder<List<AuditEvent>>(
          stream: db.auditEvents.watchForShop(shopId),
          builder: (context, snapshot) {
            final events = (snapshot.data ?? const <AuditEvent>[])
                .where((event) => (event.branchId ?? '$shopId-main') == branchId)
                .toList();
            if (events.isEmpty) {
              return Center(child: Text(l10n.t('noAuditEvents')));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.history_rounded, size: 18)),
                    title: Text(event.action, style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text('${event.entityType} • ${event.actorId}\n${event.createdAt.toLocal()}'),
                    isThreeLine: true,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
