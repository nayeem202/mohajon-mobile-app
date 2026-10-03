import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/notifications/providers/notification_providers.dart';
import '../app/app_providers.dart';
import '../localization/app_localizations.dart';
import '../services/sync_service.dart';
import '../theme/mohajon_warm_theme.dart';

class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syncStateProvider);
    final l10n = AppLocalizations.of(context);
    final (icon, color, label) = switch (state.phase) {
      SyncPhase.offline => (
          Icons.cloud_off_rounded,
          const Color(0xFFBE3A1A),
          l10n.t('offlineShort'),
        ),
      SyncPhase.syncing => (
          Icons.cloud_sync_rounded,
          MohajonWarm.goldText,
          l10n.t('syncing'),
        ),
      SyncPhase.failed => (
          Icons.sync_problem_rounded,
          MohajonWarm.red,
          l10n.t('retrySyncShort'),
        ),
      SyncPhase.idle when state.pendingCount > 0 => (
          Icons.cloud_upload_outlined,
          const Color(0xFFB45309),
          l10n.tP('pendingSyncShort', {'count': '${state.pendingCount}'}),
        ),
      SyncPhase.idle => (
          Icons.cloud_done_rounded,
          MohajonWarm.green,
          l10n.t('syncedShort'),
        ),
      SyncPhase.notSignedIn => (
          Icons.cloud_off_rounded,
          MohajonWarm.muted,
          l10n.t('signInToSync'),
        ),
    };
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: color.withValues(alpha: 0.14),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => ref.read(syncStateProvider.notifier).syncNow(),
            child: SizedBox(
              width: 34,
              height: 34,
              child: Center(
                child: state.phase == SyncPhase.syncing
                    ? SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: color,
                        ),
                      )
                    : Icon(icon, size: 17, color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NotificationBell extends ConsumerWidget {
  const NotificationBell({
    super.key,
    this.onPressed,
    this.size = 24,
  });

  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(notificationsProvider).unreadCount;
    final hasUnread = unreadCount > 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SyncStatusIndicator(),
        const SizedBox(width: 2),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: onPressed ??
                  () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      ),
              icon: Icon(
                Icons.notifications_none_rounded,
                size: size,
              ),
            ),
            if (hasUnread)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: MohajonWarm.orange,
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(
                      BorderSide(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
