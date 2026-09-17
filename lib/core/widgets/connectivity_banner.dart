import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_providers.dart';
import '../localization/app_localizations.dart';
import '../services/sync_service.dart';
import '../theme/mohajon_warm_theme.dart';

/// Persistent, global banner shown above every tab that tells the user the
/// current online/offline + sync state at a glance.
///
/// * Offline  -> amber bar "Offline mode" (+ pending changes count).
/// * Syncing  -> gold bar "Syncing data..." (Internet came back / manual).
/// * Idle     -> hidden when everything is synced, subtle bar when there are
///               unsynced local changes pending.
/// * Failed   -> red bar with a Retry action.
class ConnectivityBanner extends ConsumerWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syncStateProvider);
    final l10n = AppLocalizations.of(context);

    final (icon, color, title, subtitle, onTap) = _style(
      state,
      l10n,
      () => ref.read(syncStateProvider.notifier).syncNow(),
    );

    if (title == null) return const SizedBox.shrink();

    return Material(
      color: color.withValues(alpha: 0.20),
      child: SafeArea(
        bottom: false,
        top: true,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: color.withValues(alpha: 0.35)),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 17),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.refresh_rounded, color: color, size: 15),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  (IconData, Color, String?, String, VoidCallback?) _style(
    SyncState state,
    AppLocalizations l10n,
    VoidCallback syncNow,
  ) {
    switch (state.phase) {
      case SyncPhase.offline:
        return (
          Icons.cloud_off_rounded,
          const Color(0xFFBE3A1A),
          l10n.t('offlineModeTitle'),
          state.pendingCount > 0
              ? l10n.tP('offlineModePending', {'count': '${state.pendingCount}'})
              : l10n.t('offlineModeDesc'),
          null,
        );
      case SyncPhase.syncing:
        return (
          Icons.cloud_sync_rounded,
          MohajonWarm.goldText,
          l10n.t('syncingNowTitle'),
          l10n.t('syncingData'),
          null,
        );
      case SyncPhase.failed:
        return (
          Icons.sync_problem_rounded,
          MohajonWarm.red,
          l10n.t('syncFailed'),
          state.message.isEmpty
              ? l10n.t('syncFailedRetryHint')
              : state.message,
          syncNow,
        );
      case SyncPhase.idle:
        if (state.pendingCount > 0) {
          return (
            Icons.cloud_upload_outlined,
            const Color(0xFFB45309),
            null,
            l10n.tP('unsyncedChanges', {'count': '${state.pendingCount}'}),
            syncNow,
          );
        }
        return (Icons.cloud_done_rounded, MohajonWarm.green, null, '', null);
      case SyncPhase.notSignedIn:
        return (Icons.cloud_off_rounded, MohajonWarm.muted, null, '', null);
    }
  }
}