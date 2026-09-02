import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/investments/presentation/investment_dashboard_screen.dart';
import '../../features/expenses/presentation/expenses_screen.dart';
import '../../features/profile/presentation/profile_overview_screen.dart';
import '../../features/investors/presentation/investor_list_screen.dart';
import '../../features/settings/presentation/account_security_screen.dart';
import '../../features/settings/presentation/privacy_settings_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/staff/presentation/staff_list_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/staff/models/menu_codes.dart';
import '../../features/staff/providers/staff_providers.dart';
import '../../features/vendors/presentation/vendor_list_screen.dart';
import '../localization/app_localizations.dart';
import '../services/sync_service.dart';
import '../theme/mohajon_warm_theme.dart';
import '../widgets/async_action_state.dart';
import '../widgets/notification_bell.dart';
import '../widgets/shop_avatar.dart';
import 'app_providers.dart';

class _MoreTopBar extends StatelessWidget {
  const _MoreTopBar();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [MohajonWarm.primary, MohajonWarm.primaryPale],
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: MohajonWarm.primary.withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.grid_view_rounded,
            color: MohajonWarm.ink,
            size: 17,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.t('more'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: MohajonWarm.ink,
                ),
              ),
              Text(
                l10n.t('moreDesc'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: MohajonWarm.muted,
                ),
              ),
            ],
          ),
        ),
        const NotificationBell(),
        const SizedBox(width: 14),
        const ShopAvatar(
          radius: 17,
          backgroundColor: Color(0xFFFFFDF7),
          textColor: MohajonWarm.ink,
        ),
      ],
    );
  }
}

class FeatureHubScreen extends ConsumerStatefulWidget {
  const FeatureHubScreen({super.key});

  @override
  ConsumerState<FeatureHubScreen> createState() => _FeatureHubScreenState();
}

class _FeatureHubScreenState extends ConsumerState<FeatureHubScreen>
    with AsyncActionState<FeatureHubScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sync = ref.watch(syncStateProvider);
    final user = ref.watch(authStateProvider).value;
    final isOwner =
        user?.roles.any(
          (role) => role.toUpperCase() == 'OWNER' || role.toUpperCase() == 'ADMIN',
        ) ??
        false;
    final displayName = user?.displayName;
    final grantedMenus = ref.watch(myMenuCodesProvider).value;

    return withLoadingOverlay(
      Theme(
        data: MohajonWarm.theme(Theme.of(context)),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: MohajonWarm.pageGradient,
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -70,
                  right: -50,
                  child: IgnorePointer(
                    child: Container(
                      width: 190,
                      height: 190,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 34,
                  right: 96,
                  child: IgnorePointer(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 110,
                  left: -60,
                  child: IgnorePointer(
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                    children: [
                      const _MoreTopBar(),
                      const SizedBox(height: 18),
                      _AccountHeader(
                name: displayName?.isNotEmpty == true
                    ? (displayName ?? l10n.t('signedInAccount'))
                    : l10n.t('signedInAccount'),
                email: user?.email ?? l10n.t('noEmailAvailable'),
                        sync: sync,
                      ),
                      const SizedBox(height: 22),
                      _FeatureSection(
                        title: l10n.t('sectionOperations'),
                        children: [
                          _FeatureItem(
                            icon: Icons.store_rounded,
                            title: l10n.t('vendors'),
                            subtitle: l10n.t('vendorsSubtitle'),
                            color: MohajonWarm.goldText,
                            background: MohajonWarm.tintYellow,
                            menu: MenuCodes.vendors,
                            onTap: () => _open(const VendorListScreen()),
                          ),
                          _FeatureItem(
                            icon: Icons.payments_rounded,
                            title: l10n.t('expenses'),
                            subtitle: l10n.t('expensesSubtitle'),
                            color: MohajonWarm.orange,
                            background: MohajonWarm.tintOrange,
                            menu: MenuCodes.expenses,
                            onTap: () => _open(const ExpensesScreen()),
                          ),
                          _FeatureItem(
                            icon: Icons.people_alt_rounded,
                            title: l10n.t('investors'),
                            subtitle: l10n.t('investorsSubtitle'),
                            color: MohajonWarm.green,
                            background: MohajonWarm.tintGreen,
                            menu: MenuCodes.investors,
                            onTap: () => _open(const InvestorListScreen()),
                          ),
                          _FeatureItem(
                            icon: Icons.group_outlined,
                            title: l10n.t('staff'),
                            subtitle: l10n.t('staffSubtitle'),
                            color: MohajonWarm.goldText,
                            background: MohajonWarm.tintYellow,
                            menu: MenuCodes.staff,
                            onTap: () => _open(const StaffListScreen()),
                          ),
                          _FeatureItem(
                            icon: Icons.pie_chart_outline_rounded,
                            title: l10n.t('reports'),
                            subtitle: l10n.t('reportsSubtitle'),
                            color: MohajonWarm.goldText,
                            background: MohajonWarm.tintYellow,
                            menu: MenuCodes.reports,
                            onTap: () => _open(const ReportsScreen()),
                          ),
                        ].where((item) => hasMenuAccess(grantedMenus, item.menu, isOwner: isOwner)).toList(),
                      ),
                      const SizedBox(height: 16),
                      _FeatureSection(
                        title: l10n.t('sectionFinance'),
                        children: [
                          _FeatureItem(
                            icon: Icons.account_balance_rounded,
                            title: l10n.t('investments'),
                            subtitle: l10n.t('investmentsSubtitle'),
                            color: MohajonWarm.green,
                            background: MohajonWarm.tintGreen,
                            menu: MenuCodes.investments,
                            onTap: () => _open(const InvestmentDashboardScreen()),
                          ),
                        ].where((item) => hasMenuAccess(grantedMenus, item.menu, isOwner: isOwner)).toList(),
                      ),
                      const SizedBox(height: 16),
                      _FeatureSection(
                        title: l10n.t('sectionApp'),
                        children: [
                          _FeatureItem(
                            icon: Icons.person_rounded,
                            title: l10n.t('myProfile'),
                            subtitle: l10n.t('myProfileSubtitle'),
                            color: MohajonWarm.goldText,
                            background: MohajonWarm.tintYellow,
                            menu: MenuCodes.profile,
                            onTap: () => _open(const ProfileOverviewScreen()),
                          ),
                          _FeatureItem(
                            icon: Icons.cloud_sync_rounded,
                            title: l10n.t('syncNow'),
                            subtitle: _syncText(l10n, sync),
                            color: _syncColor(context, sync.phase),
                            onTap: _syncNow,
                          ),
                          _FeatureItem(
                            icon: Icons.lock_outline_rounded,
                            title: l10n.t('accountSecurity'),
                            subtitle: l10n.t('accountSecurityDesc'),
                            color: MohajonWarm.red,
                            background: MohajonWarm.tintRed,
                            menu: MenuCodes.security,
                            onTap: () => _open(const AccountSecurityScreen()),
                          ),
                          _FeatureItem(
                            icon: Icons.privacy_tip_outlined,
                            title: l10n.t('privacy'),
                            subtitle: l10n.t('privacyDesc'),
                            color: MohajonWarm.orange,
                            background: MohajonWarm.tintOrange,
                            menu: MenuCodes.privacy,
                            onTap: () => _open(const PrivacySettingsScreen()),
                          ),
                          _FeatureItem(
                            icon: Icons.settings_rounded,
                            title: l10n.t('settings'),
                            subtitle: l10n.t('appPreferencesMore'),
                            color: MohajonWarm.goldText,
                            background: MohajonWarm.tintYellow,
                            menu: MenuCodes.settings,
                            onTap: () => _open(const SettingsScreen()),
                          ),
                        ].where((item) => hasMenuAccess(grantedMenus, item.menu, isOwner: isOwner)).toList(),
                      ),
                      const SizedBox(height: 16),
                      _FeatureSection(
                        title: l10n.t('account'),
                        children: [
                          _FeatureItem(
                            icon: Icons.logout_rounded,
                            title: l10n.t('signOut'),
                            subtitle: l10n.t('signOutDesc'),
                            color: MohajonWarm.red,
                            background: MohajonWarm.tintRed,
                            destructive: true,
                            onTap: _signOut,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      label: l10n.t('processing'),
    );
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Color _syncColor(BuildContext context, SyncPhase phase) {
    return switch (phase) {
      SyncPhase.failed => MohajonWarm.red,
      SyncPhase.notSignedIn => MohajonWarm.orange,
      SyncPhase.offline => MohajonWarm.muted,
      SyncPhase.syncing => MohajonWarm.goldText,
      SyncPhase.idle => MohajonWarm.green,
    };
  }

  String _syncText(AppLocalizations l10n, SyncState sync) {
    if (sync.phase == SyncPhase.notSignedIn) {
      return l10n.t('signInToSync');
    }
    if (sync.phase == SyncPhase.offline) {
      return l10n.tP('offlinePending', {'count': '${sync.pendingCount}'});
    }
    if (sync.phase == SyncPhase.failed) {
      return sync.message.isEmpty ? l10n.t('syncFailed') : sync.message;
    }
    if (sync.phase == SyncPhase.syncing) return l10n.t('syncing');
    return sync.message.isEmpty
        ? l10n.tP('pendingCount', {'count': '${sync.pendingCount}'})
        : sync.message;
  }

  Future<void> _syncNow() async {
    await runBusyAction(() async {
      await ref.read(syncStateProvider.notifier).syncNow();
    });
  }

  Future<void> _signOut() async {
    final navigator = Navigator.of(context);
    await runBusyAction(() async {
      await ref.read(authServiceProvider).signOut();
      if (!mounted) return;
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    });
  }
}

class _FeatureSection extends StatelessWidget {
  const _FeatureSection({required this.title, required this.children});

  final String title;
  final List<_FeatureItem> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(label: title),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: MohajonWarm.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: MohajonWarm.goldBorder),
            boxShadow: [
              BoxShadow(
                color: MohajonWarm.ink.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    indent: 68,
                    endIndent: 14,
                    color: Color(0xFFF3ECDA),
                  ),
                _FeatureRow(item: children[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FeatureItem {
  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.background,
    this.menu,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color? background;
  final String? menu;
  final VoidCallback? onTap;
  final bool destructive;
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.item});

  final _FeatureItem item;

  @override
  Widget build(BuildContext context) {
    final destructive = item.destructive;
    final color = destructive ? MohajonWarm.red : item.color;
    final background = destructive
        ? MohajonWarm.tintRed
        : (item.background ?? item.color.withValues(alpha: 0.12));
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.14),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(item.icon, color: color, size: 21),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: MohajonWarm.ink,
                      ),
                    ),
                    if (item.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: MohajonWarm.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (item.onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: MohajonWarm.muted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 15,
          decoration: BoxDecoration(
            color: MohajonWarm.primary,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w900,
            color: MohajonWarm.ink,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: DashedLine(),
        ),
      ],
    );
  }
}

class DashedLine extends StatelessWidget {
  const DashedLine({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 5.0;
        const dashGap = 4.0;
        final count =
            (constraints.maxWidth / (dashWidth + dashGap)).floor();
        return Row(
          children: [
            for (var i = 0; i < count; i++)
              Container(
                width: dashWidth,
                height: 1.2,
                margin: const EdgeInsets.only(right: dashGap),
                color: MohajonWarm.goldBorder,
              ),
          ],
        );
      },
    );
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({
    required this.name,
    required this.email,
    required this.sync,
  });

  final String name;
  final String email;
  final SyncState sync;

  String _syncLabel(AppLocalizations l10n) {
    return switch (sync.phase) {
      SyncPhase.failed => l10n.t('syncFailed'),
      SyncPhase.notSignedIn => l10n.t('signInToSync'),
      SyncPhase.offline => 'Offline • ${sync.pendingCount}',
      SyncPhase.syncing => l10n.t('syncing'),
      SyncPhase.idle => 'Synced',
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final statusColor = switch (sync.phase) {
      SyncPhase.failed => MohajonWarm.red,
      SyncPhase.notSignedIn => MohajonWarm.orange,
      SyncPhase.offline => MohajonWarm.muted,
      SyncPhase.syncing => MohajonWarm.goldText,
      SyncPhase.idle => MohajonWarm.green,
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MohajonWarm.tintYellow, MohajonWarm.card],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MohajonWarm.goldBorder),
        boxShadow: [
          BoxShadow(
            color: MohajonWarm.primary.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const ShopAvatar(radius: 27, backgroundColor: Colors.white),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15.5,
                    color: MohajonWarm.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MohajonWarm.muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: statusColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_done_rounded, size: 13, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  _syncLabel(l10n),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
