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
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [MohajonWarm.primary, MohajonWarm.primaryPale],
            ),
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(
                color: MohajonWarm.primary.withValues(alpha: 0.32),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.grid_view_rounded,
            color: MohajonWarm.ink,
            size: 18,
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
      ],
    );
  }
}

class FeatureHubScreen extends ConsumerStatefulWidget {
  const FeatureHubScreen({
    super.key,
    this.tourVendorsKey,
    this.tourExpensesKey,
    this.tourInvestorsKey,
    this.tourStaffKey,
    this.tourReportsKey,
    this.tourInvestmentsKey,
    this.tourSettingsKey,
    this.scrollController,
  });

  final GlobalKey? tourVendorsKey;
  final GlobalKey? tourExpensesKey;
  final GlobalKey? tourInvestorsKey;
  final GlobalKey? tourStaffKey;
  final GlobalKey? tourReportsKey;
  final GlobalKey? tourInvestmentsKey;
  final GlobalKey? tourSettingsKey;
  final ScrollController? scrollController;

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

    final operations = <_FeatureItem>[
      _FeatureItem(
        icon: Icons.store_rounded,
        title: l10n.t('vendors'),
        subtitle: l10n.t('vendorsSubtitle'),
        color: MohajonWarm.goldText,
        background: MohajonWarm.tintYellow,
        menu: MenuCodes.vendors,
        onTap: () => _open(const VendorListScreen()),
        itemKey: widget.tourVendorsKey,
      ),
      _FeatureItem(
        icon: Icons.payments_rounded,
        title: l10n.t('expenses'),
        subtitle: l10n.t('expensesSubtitle'),
        color: MohajonWarm.orange,
        background: MohajonWarm.tintOrange,
        menu: MenuCodes.expenses,
        onTap: () => _open(const ExpensesScreen()),
        itemKey: widget.tourExpensesKey,
      ),
      _FeatureItem(
        icon: Icons.people_alt_rounded,
        title: l10n.t('investors'),
        subtitle: l10n.t('investorsSubtitle'),
        color: MohajonWarm.green,
        background: MohajonWarm.tintGreen,
        menu: MenuCodes.investors,
        onTap: () => _open(const InvestorListScreen()),
        itemKey: widget.tourInvestorsKey,
      ),
      _FeatureItem(
        icon: Icons.group_outlined,
        title: l10n.t('staff'),
        subtitle: l10n.t('staffSubtitle'),
        color: MohajonWarm.goldText,
        background: MohajonWarm.tintYellow,
        menu: MenuCodes.staff,
        onTap: () => _open(const StaffListScreen()),
        itemKey: widget.tourStaffKey,
      ),
    ].where((item) => hasMenuAccess(grantedMenus, item.menu, isOwner: isOwner)).toList();

    final finance = <_FeatureItem>[
      _FeatureItem(
        icon: Icons.account_balance_rounded,
        title: l10n.t('investments'),
        subtitle: l10n.t('investmentsSubtitle'),
        color: MohajonWarm.ink,
        background: MohajonWarm.tintGreen,
        menu: MenuCodes.investments,
        onTap: () => _open(const InvestmentDashboardScreen()),
        itemKey: widget.tourInvestmentsKey,
      ),
    ].where((item) => hasMenuAccess(grantedMenus, item.menu, isOwner: isOwner)).toList();

    final reports = <_FeatureItem>[
      _FeatureItem(
        icon: Icons.pie_chart_outline_rounded,
        title: l10n.t('reports'),
        subtitle: l10n.t('reportsSubtitle'),
        color: MohajonWarm.ink,
        background: MohajonWarm.tintYellow,
        menu: MenuCodes.reports,
        onTap: () => _open(const ReportsScreen()),
        itemKey: widget.tourReportsKey,
      ),
    ].where((item) => hasMenuAccess(grantedMenus, item.menu, isOwner: isOwner)).toList();

    final appItems = <_FeatureItem>[
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
        itemKey: widget.tourSettingsKey,
      ),
    ].where((item) => hasMenuAccess(grantedMenus, item.menu, isOwner: isOwner)).toList();

    final accountItems = <_FeatureItem>[
      _FeatureItem(
        icon: Icons.logout_rounded,
        title: l10n.t('signOut'),
        subtitle: l10n.t('signOutDesc'),
        color: MohajonWarm.red,
        background: MohajonWarm.tintRed,
        destructive: true,
        onTap: _confirmSignOut,
      ),
    ];

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
                    controller: widget.scrollController,
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                    children: [
                      const _MoreTopBar(),
                      const SizedBox(height: 16),
                      _Entrance(
                        child: _PremiumHero(
                          name: displayName?.isNotEmpty == true
                              ? (displayName ?? l10n.t('signedInAccount'))
                              : l10n.t('signedInAccount'),
                          email: user?.email ?? l10n.t('noEmailAvailable'),
                          sync: sync,
                          onSyncTap: _syncNow,
                        ),
                      ),
                      const SizedBox(height: 26),
                      if (operations.isNotEmpty) ...[
                        const _SectionHeader(label: 'operations', hasSubtitle: true),
                        const SizedBox(height: 12),
                        _Entrance(
                          delay: const Duration(milliseconds: 90),
                          child: _FeatureGrid(
                            items: operations,
                            mainAxisExtent: 144,
                          ),
                        ),
                        const SizedBox(height: 22),
                      ],
                      if (finance.isNotEmpty) ...[
                        const _SectionHeader(label: 'finance'),
                        const SizedBox(height: 12),
                        _Entrance(
                          delay: const Duration(milliseconds: 160),
                          child: _WideCard(item: finance.first),
                        ),
                        const SizedBox(height: 22),
                      ],
                      if (reports.isNotEmpty) ...[
                        const _SectionHeader(label: 'reports'),
                        const SizedBox(height: 12),
                        _Entrance(
                          delay: const Duration(milliseconds: 210),
                          child: _WideCard(
                            item: reports.first,
                            palette: _WideCard.reportsPalette,
                          ),
                        ),
                        const SizedBox(height: 22),
                      ],
                      if (appItems.isNotEmpty) ...[
                        const _SectionHeader(label: 'app'),
                        const SizedBox(height: 12),
                        _Entrance(
                          delay: const Duration(milliseconds: 230),
                          child: _FeatureGrid(
                            items: appItems,
                            compact: true,
                            mainAxisExtent: 118,
                          ),
                        ),
                        const SizedBox(height: 22),
                      ],
                      if (accountItems.isNotEmpty) ...[
                        const _SectionHeader(label: 'account'),
                        const SizedBox(height: 12),
                        _Entrance(
                          delay: const Duration(milliseconds: 300),
                          child: _DangerCard(item: accountItems.first),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      label: l10n.t('syncing'),
    );
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _syncNow() async {
    await runBusyAction(() async {
      await ref.read(syncStateProvider.notifier).syncNow();
    });
  }

  void _confirmSignOut() {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return PopScope(
          canPop: true,
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.all(24),
                width: 320,
                decoration: BoxDecoration(
                  color: MohajonWarm.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: MohajonWarm.goldBorder),
                  boxShadow: [
                    BoxShadow(
                      color: MohajonWarm.ink.withValues(alpha: 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: MohajonWarm.tintRed,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: MohajonWarm.red,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.t('signOutMiddle'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: MohajonWarm.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.t('signOutConfirm'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: MohajonWarm.muted,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: OutlinedButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: const Color(0xFFF0ECE6),
                                foregroundColor: const Color(0xFF525252),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide.none,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: Text(l10n.t('cancel')),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: FilledButton(
                              onPressed: () {
                                Navigator.of(dialogContext).pop();
                                _signOut();
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: MohajonWarm.red,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: Text(l10n.t('signOutMiddle')),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
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

/// Data definition of a single destination in the hub.
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
    this.itemKey,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color? background;
  final String? menu;
  final VoidCallback? onTap;
  final bool destructive;
  final GlobalKey? itemKey;
}

/// Premium section header — gradient pill accent + letter-spaced label + dash.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.hasSubtitle = false});

  final String label;
  final bool hasSubtitle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = switch (label) {
      'operations' => l10n.t('sectionOperations'),
      'finance' => l10n.t('sectionFinance'),
      'reports' => l10n.t('reports'),
      'app' => l10n.t('sectionApp'),
      'account' => l10n.t('account'),
      _ => label,
    };
    return Row(
      children: [
        Container(
          width: 5,
          height: 18,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [MohajonWarm.primarySoft, MohajonWarm.primary],
            ),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: MohajonWarm.primary.withValues(alpha: 0.45),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(width: 9),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w900,
            color: MohajonWarm.ink,
          ),
        ),
        if (hasSubtitle) ...[
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.t('quickActionsSubtitle'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: MohajonWarm.muted,
              ),
            ),
          ),
        ] else ...[
          const SizedBox(width: 10),
          const Expanded(child: DashedLine()),
        ],
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

/// Staggered entrance: fades + slides the child in shortly after mount.
class _Entrance extends StatefulWidget {
  const _Entrance({
    required this.child,
    this.delay = const Duration(milliseconds: 40),
  });

  final Widget child;
  final Duration delay;

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _shown ? Offset.zero : const Offset(0, 0.10),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _shown ? 1 : 0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Subtle press-down scale micro-interaction wrapped around tappable cards.
class _PressScale extends StatefulWidget {
  const _PressScale({required this.child});

  final Widget child;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _down ? 0.975 : 1.0,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOutCubic,
      child: Listener(
        onPointerDown: (_) => setState(() => _down = true),
        onPointerUp: (_) => setState(() => _down = false),
        onPointerCancel: (_) => setState(() => _down = false),
        child: widget.child,
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({
    required this.items,
    this.compact = false,
    required this.mainAxisExtent,
  });

  final List<_FeatureItem> items;
  final bool compact;
  final double mainAxisExtent;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        mainAxisExtent: mainAxisExtent,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) =>
          _PremiumTile(item: items[index], compact: compact),
    );
  }
}

/// Premum feature tile: glass sheen, gradient icon tile, arrow affordance.
class _PremiumTile extends StatelessWidget {
  const _PremiumTile({required this.item, this.compact = false});

  final _FeatureItem item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = item.destructive ? MohajonWarm.red : item.color;
    final iconSize = compact ? 20.0 : 22.0;
    final tileSize = compact ? 40.0 : 46.0;
    return KeyedSubtree(
      key: item.itemKey,
      child: _PressScale(
        child: GestureDetector(
          onTap: item.onTap,
          child: Container(
            decoration: BoxDecoration(
              color: MohajonWarm.card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: MohajonWarm.goldBorder),
              boxShadow: [
                BoxShadow(
                  color: MohajonWarm.ink.withValues(alpha: 0.07),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Soft glass sheen across the top.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(22),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.60),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Faint tinted backdrop blob for depth.
                Positioned(
                  right: -22,
                  bottom: -26,
                  child: IgnorePointer(
                    child: Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(compact ? 12 : 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: tileSize,
                            height: tileSize,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  color,
                                  color.withValues(alpha: 0.72),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(
                                tileSize * 0.32,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.32),
                                  blurRadius: 12,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Icon(
                              item.icon,
                              color: Colors.white,
                              size: iconSize,
                            ),
                          ),
                          const Spacer(),
                          if (item.onTap != null)
                            Container(
                              width: 26,
                              height: 26,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF7F2E4),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 14,
                                color: MohajonWarm.muted,
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: compact ? 10 : 12),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 13.5 : 14.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                          color: MohajonWarm.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.subtitle,
                        maxLines: compact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 11 : 11.5,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: MohajonWarm.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rich finance banner — deep gradient, white text, sheen accents.
class _WideCard extends StatelessWidget {
  const _WideCard({required this.item, this.palette = financePalette});

  final _FeatureItem item;
  final _WidePalette palette;

  static const financePalette = _WidePalette(
    start: Color(0xFF07523C),
    end: Color(0xFF0E8A63),
    shadow: MohajonWarm.green,
    icon: Color(0xFF07523C),
  );

  static const reportsPalette = _WidePalette(
    start: Color(0xFF3A2E6B),
    end: Color(0xFF6B58B8),
    shadow: Color(0xFF4C3FA0),
    icon: Color(0xFF3A2E6B),
  );

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: item.itemKey,
      child: _PressScale(
        child: GestureDetector(
          onTap: item.onTap,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [palette.start, palette.end],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: palette.shadow.withValues(alpha: 0.35),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned(
                  top: -30,
                  right: -22,
                  child: IgnorePointer(
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -34,
                  left: 70,
                  child: IgnorePointer(
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  right: 46,
                  child: IgnorePointer(
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.18),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: MohajonWarm.ink.withValues(alpha: 0.18),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Icon(
                          item.icon,
                          color: palette.icon,
                          size: 26,
                        ),
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
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.80),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          size: 17,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WidePalette {
  const _WidePalette({
    required this.start,
    required this.end,
    required this.shadow,
    required this.icon,
  });

  final Color start;
  final Color end;
  final Color shadow;
  final Color icon;
}

class _DangerCard extends StatelessWidget {
  const _DangerCard({required this.item});

  final _FeatureItem item;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: item.itemKey,
      child: _PressScale(
        child: GestureDetector(
          onTap: item.onTap,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [MohajonWarm.tintRed, MohajonWarm.card],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: MohajonWarm.red.withValues(alpha: 0.22),
              ),
              boxShadow: [
                BoxShadow(
                  color: MohajonWarm.red.withValues(alpha: 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: MohajonWarm.red.withValues(alpha: 0.14),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(item.icon, color: MohajonWarm.red, size: 22),
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
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: MohajonWarm.red,
                          ),
                        ),
                        const SizedBox(height: 3),
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
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumHero extends StatelessWidget {
  const _PremiumHero({
    required this.name,
    required this.email,
    required this.sync,
    this.onSyncTap,
  });

  final String name;
  final String email;
  final SyncState sync;
  final VoidCallback? onSyncTap;

  Color get _statusColor {
    return switch (sync.phase) {
      SyncPhase.failed => MohajonWarm.red,
      SyncPhase.notSignedIn => MohajonWarm.orange,
      SyncPhase.offline => MohajonWarm.muted,
      SyncPhase.syncing => MohajonWarm.goldText,
      SyncPhase.idle => MohajonWarm.green,
    };
  }

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
    final statusColor = _statusColor;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MohajonWarm.primary,
            MohajonWarm.primarySoft,
            Color(0xFFFFE36E),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFFFE9A8)),
        boxShadow: [
          BoxShadow(
            color: MohajonWarm.primary.withValues(alpha: 0.34),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            top: -36,
            right: -24,
            child: IgnorePointer(
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.20),
                ),
              ),
            ),
          ),
          Positioned(
            top: 26,
            right: 42,
            child: IgnorePointer(
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -42,
            left: 56,
            child: IgnorePointer(
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),
          ),
          Positioned(
            top: 14,
            right: 14,
            child: IgnorePointer(
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(26),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.35),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.white, Color(0xFFFFD94D)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: MohajonWarm.ink.withValues(alpha: 0.22),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const ShopAvatar(
                        radius: 29,
                        backgroundColor: Color(0xFFFFF6D8),
                        textColor: MohajonWarm.ink,
                      ),
                    ),
                  ),
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
                            fontSize: 17.5,
                            letterSpacing: -0.3,
                            color: MohajonWarm.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          l10n.t('hubHeroTagline'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF6E5B1E),
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _PressScale(
                    child: GestureDetector(
                      onTap: onSyncTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: MohajonWarm.ink.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (sync.phase == SyncPhase.syncing)
                              SizedBox(
                                width: 13,
                                height: 13,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: statusColor,
                                ),
                              )
                            else
                              Icon(
                                Icons.cloud_done_rounded,
                                size: 14,
                                color: statusColor,
                              ),
                            const SizedBox(width: 5),
                            Text(
                              _syncLabel(l10n),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 1.2,
                              height: 12,
                              color: const Color(0xFFEDE4C8),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.sync_rounded,
                              size: 14,
                              color: Color(0xFF6E5B1E),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6E5B1E),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}