import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/shop_profile.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/widgets/async_action_state.dart';
import '../../auth/presentation/login_screen.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/shop_profile_providers.dart';
import 'shop_profile_screen.dart';

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
    final shopProfile = ref.watch(shopProfileProvider);
    final profile = shopProfile.value;

    return withLoadingOverlay(
      Scaffold(
        appBar: AppBar(title: Text(l10n.t('settings'))),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: Text(user?.displayName?.isNotEmpty == true
                    ? user!.displayName!
                    : 'Signed in account'),
                subtitle: Text(user?.email ?? 'No email available'),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: isBusy
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ShopProfileScreen(),
                          ),
                        );
                      },
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
                        child: Icon(
                          Icons.store_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Shop profile',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _shopProfileSummary(shopProfile, profile),
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
                              style: const TextStyle(fontWeight: FontWeight.w900),
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

  String _shopProfileSummary(
    AsyncValue<ShopProfile?> shopProfile,
    ShopProfile? profile,
  ) {
    if (shopProfile.isLoading) {
      return 'Loading current shop details...';
    }
    if (shopProfile.hasError) {
      return 'Could not load shop details.';
    }
    if (profile == null) {
      return 'Tap to add shop name, location, and phone number.';
    }
    final name = (profile.shopName as String).trim();
    final location = (profile.location as String).trim();
    if (name.isEmpty && location.isEmpty) {
      return 'Tap to complete your shop details.';
    }
    if (location.isEmpty) return name;
    if (name.isEmpty) return location;
    return '$name • $location';
  }

  Future<void> _syncNow() async {
    await runBusyAction(() async {
      await ref.read(syncStateProvider.notifier).syncNow();
    });
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
