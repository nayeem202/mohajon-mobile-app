import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_providers.dart';
import '../localization/app_localizations.dart';
import '../services/sync_service.dart';
import '../theme/mohajon_warm_theme.dart';

/// Compact global connectivity indicator shown above every tab.
/// It deliberately avoids a large explanatory banner: the icon/status chip
/// is enough for everyday use, while tapping it retries a pending sync.
class ConnectivityBanner extends ConsumerWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syncStateProvider);
    final l10n = AppLocalizations.of(context);

    final (icon, color, label, onTap) = _style(
      state,
      l10n,
      () => ref.read(syncStateProvider.notifier).syncNow(),
    );

    if (label == null) return const SizedBox.shrink();

    return ColoredBox(
      color: MohajonWarm.primary,
      child: SafeArea(
        top: true,
        bottom: false,
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
            child: Material(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width - 16,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (state.phase == SyncPhase.syncing)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: color,
                        ),
                      )
                    else
                      Icon(icon, color: color, size: 15),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (onTap != null) ...[
                      const SizedBox(width: 5),
                      Icon(Icons.refresh_rounded, color: color, size: 14),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
            ),
          ),
        ),
      );
  }

  (IconData, Color, String?, VoidCallback?) _style(
    SyncState state,
    AppLocalizations l10n,
    VoidCallback syncNow,
  ) {
    switch (state.phase) {
      case SyncPhase.offline:
        return (
          Icons.cloud_off_rounded,
          const Color(0xFFBE3A1A),
          state.pendingCount > 0
              ? l10n.tP('pendingSyncShort', {'count': '${state.pendingCount}'})
              : l10n.t('offlineShort'),
          syncNow,
        );
      case SyncPhase.syncing:
        return (
          Icons.cloud_sync_rounded,
          MohajonWarm.goldText,
          l10n.t('syncing'),
          null,
        );
      case SyncPhase.failed:
        return (
          Icons.sync_problem_rounded,
          MohajonWarm.red,
          l10n.t('retrySyncShort'),
          syncNow,
        );
      case SyncPhase.idle:
        if (state.pendingCount > 0) {
          return (
            Icons.cloud_upload_outlined,
            const Color(0xFFB45309),
            l10n.tP('pendingSyncShort', {'count': '${state.pendingCount}'}),
            syncNow,
          );
        }
        return (Icons.cloud_done_rounded, MohajonWarm.green, l10n.t('syncedShort'), syncNow);
      case SyncPhase.notSignedIn:
        return (Icons.cloud_off_rounded, MohajonWarm.muted, null, null);
    }
  }
}
