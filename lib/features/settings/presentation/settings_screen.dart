import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/admin_service.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/widgets/async_action_state.dart';
import '../../auth/presentation/login_screen.dart';
import '../../auth/providers/auth_providers.dart';
import 'account_security_screen.dart';
import 'customer_rules_settings_screen.dart';
import 'privacy_settings_screen.dart';


class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with AsyncActionState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final sync = ref.watch(syncStateProvider);
    final user = ref.watch(authStateProvider).value;

    return withLoadingOverlay(
      Scaffold(
        appBar: AppBar(title: Text(l10n.t('settings'))),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: Text(
                  user?.displayName?.isNotEmpty == true
                      ? user!.displayName!
                      : 'Signed in account',
                ),
                subtitle: Text(user?.email ?? 'No email available'),
              ),
            ),
            const SizedBox(height: 12),
            _SettingsActionCard(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy',
              subtitle: 'Current login location and phone model details',
              onTap: isBusy
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PrivacySettingsScreen(),
                        ),
                      );
                    },
            ),
            const SizedBox(height: 12),
            _SettingsActionCard(
              icon: Icons.lock_outline,
              title: 'Account security',
              subtitle: 'Set or change your account password',
              onTap: isBusy
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AccountSecurityScreen(),
                        ),
                      );
                    },
            ),
            const SizedBox(height: 12),
            _SettingsActionCard(
              icon: Icons.local_offer_rounded,
              title: 'Customer Rules',
              subtitle: 'Set spend thresholds to auto-tag clients as Regular or VIP',
              onTap: isBusy
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CustomerRulesSettingsScreen(),
                        ),
                      );
                    },
            ),
            const SizedBox(height: 12),
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: isBusy ? null : _syncNow,
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
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
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: null,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.translate_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.t('language'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SegmentedButton<String>(
                              segments: [
                                ButtonSegment(
                                  value: 'en',
                                  label: Text(l10n.t('english')),
                                ),
                                ButtonSegment(
                                  value: 'bn',
                                  label: Text(l10n.t('bangla')),
                                ),
                              ],
                              selected: {locale.languageCode},
                              onSelectionChanged: (value) {
                                final code = value.first;
                                ref
                                    .read(localDatabaseProvider)
                                    .settings
                                    .put('languageCode', code);
                                ref.read(localeProvider.notifier).state =
                                    Locale(code);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: isBusy ? null : _signOut,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.logout_rounded,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sign out',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            SizedBox(height: 4),
                            Text('Log out from the current account'),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            _SettingsActionCard(
              icon: Icons.delete_sweep_rounded,
              title: 'Clear All Data',
              subtitle: 'Delete all shop data from Firebase',
              onTap: isBusy ? null : _clearData,
            ),
          ],
        ),
      ),
      label: 'Processing...',
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

  Future<void> _syncNow() async {
    await runBusyAction(() async {
      await ref.read(syncStateProvider.notifier).syncNow();
    });
  }

  Future<void> _clearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will permanently delete all products, customers, sales, '
          'vendors, investments, investors, and all other data from Firebase. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final deleteCtrl = TextEditingController();
    final secondConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final typed = deleteCtrl.text.trim();
          return AlertDialog(
            title: const Text('Final Confirmation'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Type DELETE below to confirm you want to remove all shop data. This cannot be undone.',
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: deleteCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Type DELETE',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDlgState(() {}),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: typed == 'DELETE'
                    ? () => Navigator.of(ctx).pop(true)
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                ),
                child: const Text('Delete Everything'),
              ),
            ],
          );
        },
      ),
    );
    if (secondConfirm != true) return;

    try {
      final result = await runBusyAction(() async {
        return ref.read(adminServiceProvider).clearAllShopData();
      });
      if (mounted && result != null) {
        final deleted = result['deleted'] as int;
        final failed = result['failed'] as int;
        final errors = result['errors'] as List<String>;
        final msg = failed > 0
            ? 'Deleted $deleted records ($failed failed)'
            : 'Deleted $deleted records successfully';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: failed > 0
                ? const Color(0xFFDC2626)
                : const Color(0xFF047857),
          ),
        );
        if (errors.isNotEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errors.first),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $error')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    await runBusyAction(() async {
      await ref.read(authServiceProvider).signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    });
  }
}

class _SettingsActionCard extends StatelessWidget {
  const _SettingsActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
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
    );
  }
}
