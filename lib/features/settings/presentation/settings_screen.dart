import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/sync_service.dart';
import '../../auth/presentation/login_screen.dart';
import '../../auth/providers/auth_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final sync = ref.watch(syncStateProvider);
    final user = ref.watch(authStateProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('settings'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.translate_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        l10n.t('language'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'en',
                        label: Text(l10n.t('english')),
                      ),
                      ButtonSegment(value: 'bn', label: Text(l10n.t('bangla'))),
                    ],
                    selected: {locale.languageCode},
                    onSelectionChanged: (value) {
                      final code = value.first;
                      ref
                          .read(localDatabaseProvider)
                          .settings
                          .put('languageCode', code);
                      ref.read(localeProvider.notifier).state = Locale(code);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: Text(user?.displayName?.isNotEmpty == true
                  ? user!.displayName!
                  : 'Signed in account'),
              subtitle: Text(user?.email ?? 'No email available'),
              trailing: TextButton(
                onPressed: () async {
                  await ref.read(authServiceProvider).signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (_) => false,
                    );
                  }
                },
                child: const Text('Sign out'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => ref.read(syncStateProvider.notifier).syncNow(),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _syncColor(
                          context,
                          sync.phase,
                        ).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.cloud_sync_rounded,
                        color: _syncColor(context, sync.phase),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.t('syncNow'),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _syncText(sync),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.admin_panel_settings_outlined),
              title: Text('Roles'),
              subtitle: Text(
                'Owner and staff users are stored under shops/{shopId}/users.',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _syncColor(BuildContext context, SyncPhase phase) {
    final colors = Theme.of(context).colorScheme;
    return switch (phase) {
      SyncPhase.failed => colors.error,
      SyncPhase.firebaseNotConfigured => colors.tertiary,
      SyncPhase.offline => colors.onSurfaceVariant,
      SyncPhase.syncing => colors.primary,
      SyncPhase.idle => colors.secondary,
    };
  }

  String _syncText(SyncState sync) {
    if (sync.phase == SyncPhase.firebaseNotConfigured) {
      return 'Firebase not configured. Add the Spark project files, then sync.';
    }
    if (sync.phase == SyncPhase.offline) {
      return 'Offline. ${sync.pendingCount} records will sync later.';
    }
    if (sync.phase == SyncPhase.failed) {
      return sync.message.isEmpty ? 'Sync failed.' : sync.message;
    }
    if (sync.phase == SyncPhase.syncing) {
      return 'Uploading and downloading changed records...';
    }
    return sync.message.isEmpty
        ? '${sync.pendingCount} pending records'
        : sync.message;
  }
}
