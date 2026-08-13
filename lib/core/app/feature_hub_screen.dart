import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/investments/presentation/investment_dashboard_screen.dart';
import '../../features/expenses/presentation/expenses_screen.dart';
import '../../features/profile/presentation/profile_overview_screen.dart';
import '../../features/customers/presentation/customer_form_screen.dart';
import '../../features/customers/presentation/customer_list_screen.dart';
import '../../features/pos/presentation/pos_screen.dart';
import '../../features/products/presentation/barcode_scan_screen.dart';
import '../../features/products/presentation/product_form_screen.dart';
import '../../features/products/presentation/product_list_screen.dart';
import '../../features/investors/presentation/investor_list_screen.dart';
import '../../features/settings/presentation/account_security_screen.dart';
import '../../features/settings/presentation/privacy_settings_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/staff/presentation/staff_list_screen.dart';
import '../../features/staff/models/menu_codes.dart';
import '../../features/staff/providers/staff_providers.dart';
import '../../features/vendors/presentation/vendor_list_screen.dart';
import '../localization/app_localizations.dart';
import '../services/sync_service.dart';
import '../widgets/async_action_state.dart';
import '../widgets/notification_bell.dart';
import '../widgets/shop_avatar.dart';
import 'app_providers.dart';

class _MoreTopBar extends StatelessWidget {
  const _MoreTopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF97316), Color(0xFFEA580C)],
            ),
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF97316).withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.grid_view_rounded,
            color: Colors.white,
            size: 19,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'More',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF101828),
                ),
              ),
              Text(
                'Everything in one place',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8A8A8A),
                ),
              ),
            ],
          ),
        ),
        const NotificationBell(),
        const SizedBox(width: 14),
        const ShopAvatar(),
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
    final colors = Theme.of(context).colorScheme;
    final locale = ref.watch(localeProvider);
    final sync = ref.watch(syncStateProvider);
    final user = ref.watch(authStateProvider).value;
    final themeMode = ref.watch(themeModeProvider);
    final grantedMenus = ref.watch(myMenuCodesProvider).value;

    return withLoadingOverlay(
      Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            children: [
              const _MoreTopBar(),
              const SizedBox(height: 18),
              _AccountHeader(
                name: user?.displayName?.isNotEmpty == true
                    ? user!.displayName!
                    : 'Signed in account',
                email: user?.email ?? 'No email available',
                sync: sync,
              ),
              const SizedBox(height: 22),
              _FeatureSection(
                title: l10n.t('sectionOperations'),
                children: [
                  _FeatureItem(
                    icon: Icons.inventory_2_rounded,
                    title: l10n.t('products'),
                    subtitle: l10n.t('productsDesc'),
                    color: colors.primary,
                    menu: MenuCodes.products,
                    onTap: () => _open(const ProductListScreen()),
                  ),
                  _FeatureItem(
                    icon: Icons.add_box_rounded,
                    title: l10n.t('addProduct'),
                    subtitle: 'Create or restock item',
                    color: colors.secondary,
                    menu: MenuCodes.addProduct,
                    onTap: () => _open(const ProductFormScreen()),
                  ),
                  _FeatureItem(
                    icon: Icons.people_alt_rounded,
                    title: l10n.t('customers'),
                    subtitle: l10n.t('customersDesc'),
                    color: colors.tertiary,
                    menu: MenuCodes.clients,
                    onTap: () => _open(const CustomerListScreen()),
                  ),
                  _FeatureItem(
                    icon: Icons.person_add_alt_1_rounded,
                    title: l10n.t('addCustomer'),
                    subtitle: 'New customer profile',
                    color: colors.tertiary,
                    menu: MenuCodes.addCustomer,
                    onTap: () => _open(const CustomerFormScreen()),
                  ),
                  _FeatureItem(
                    icon: Icons.store_rounded,
                    title: 'Vendors',
                    subtitle: 'Manage suppliers and purchases',
                    color: const Color(0xFFB45309),
                    menu: MenuCodes.vendors,
                    onTap: () => _open(const VendorListScreen()),
                  ),
                  _FeatureItem(
                    icon: Icons.payments_rounded,
                    title: 'Expenses',
                    subtitle: 'Track rent, salaries, and bills',
                    color: const Color(0xFFF97316),
                    menu: MenuCodes.expenses,
                    onTap: () => _open(const ExpensesScreen()),
                  ),
                  _FeatureItem(
                    icon: Icons.people_alt_rounded,
                    title: 'Investors',
                    subtitle: 'Track investors and payouts',
                    color: const Color(0xFF047857),
                    menu: MenuCodes.investors,
                    onTap: () => _open(const InvestorListScreen()),
                  ),
                  _FeatureItem(
                    icon: Icons.qr_code_scanner_rounded,
                    title: 'Barcode scan',
                    subtitle: 'Find code from camera',
                    color: colors.primary,
                    menu: MenuCodes.barcode,
                    onTap: () => _open(const BarcodeScanScreen()),
                  ),
                ].where((item) => hasMenuAccess(grantedMenus, item.menu)).toList(),
              ),
              const SizedBox(height: 16),
              _FeatureSection(
                title: l10n.t('sectionFinance'),
                children: [
                  _FeatureItem(
                    icon: Icons.shopping_cart_checkout_rounded,
                    title: l10n.t('sales'),
                    subtitle: 'POS cart and invoice',
                    color: colors.primary,
                    menu: MenuCodes.sales,
                    onTap: () => _open(const PosScreen()),
                  ),
                  _FeatureItem(
                    icon: Icons.account_balance_wallet_rounded,
                    title: l10n.t('due'),
                    subtitle: l10n.t('duesDesc'),
                    color: colors.tertiary,
                    menu: MenuCodes.due,
                    onTap: () => _open(const CustomerListScreen()),
                  ),
                  _FeatureItem(
                    icon: Icons.account_balance_rounded,
                    title: 'Investments',
                    subtitle: 'Manage investments and ROI',
                    color: const Color(0xFF0F766E),
                    menu: MenuCodes.investments,
                    onTap: () => _open(const InvestmentDashboardScreen()),
                  ),
                ].where((item) => hasMenuAccess(grantedMenus, item.menu)).toList(),
              ),
              const SizedBox(height: 16),
              _FeatureSection(
                title: l10n.t('sectionApp'),
                children: [
                  _FeatureItem(
                    icon: Icons.person_rounded,
                    title: 'My Profile',
                    subtitle: 'View and edit your profile',
                    color: colors.primary,
                    menu: MenuCodes.profile,
                    onTap: () => _open(const ProfileOverviewScreen()),
                  ),
                  _FeatureItem(
                    icon: Icons.cloud_sync_rounded,
                    title: l10n.t('syncNow'),
                    subtitle: _syncText(sync),
                    color: _syncColor(context, sync.phase),
                    onTap: _syncNow,
                  ),
                  _FeatureItem(
                    icon: Icons.dark_mode_rounded,
                    title: 'Theme',
                    subtitle: _themeLabel(themeMode),
                    color: colors.primary,
                    trailing: SegmentedButton<ThemeMode>(
                      style: _segmentStyle(),
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode_outlined, size: 16),
                        ),
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.settings_suggest_outlined, size: 16),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode_outlined, size: 16),
                        ),
                      ],
                      selected: {themeMode},
                      onSelectionChanged: (value) {
                        final mode = value.first;
                        ref.read(themeModeProvider.notifier).state = mode;
                        ref
                            .read(localDatabaseProvider)
                            .settings
                            .put('themeMode', mode.name);
                      },
                    ),
                  ),
                  _FeatureItem(
                    icon: Icons.translate_rounded,
                    title: l10n.t('language'),
                    subtitle: locale.languageCode == 'bn' ? 'Bangla' : 'English',
                    color: colors.tertiary,
                    trailing: SegmentedButton<String>(
                      style: _segmentStyle(),
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
                  ),
                  _FeatureItem(
                    icon: Icons.lock_outline_rounded,
                    title: l10n.t('accountSecurity'),
                    subtitle: l10n.t('accountSecurityDesc'),
                    color: colors.primary,
                    menu: MenuCodes.security,
                    onTap: () => _open(const AccountSecurityScreen()),
                  ),
                  _FeatureItem(
                    icon: Icons.privacy_tip_outlined,
                    title: l10n.t('privacy'),
                    subtitle: l10n.t('privacyDesc'),
                    color: colors.tertiary,
                    menu: MenuCodes.privacy,
                    onTap: () => _open(const PrivacySettingsScreen()),
                  ),
                  _FeatureItem(
                    icon: Icons.group_outlined,
                    title: 'Staff',
                    subtitle: 'Manage team members',
                    color: const Color(0xFFB45309),
                    menu: MenuCodes.staff,
                    onTap: () => _open(const StaffListScreen()),
                  ),
                  _FeatureItem(
                    icon: Icons.settings_rounded,
                    title: 'Settings',
                    subtitle: 'App preferences & more',
                    color: colors.primary,
                    menu: MenuCodes.settings,
                    onTap: () => _open(const SettingsScreen()),
                  ),
                ].where((item) => hasMenuAccess(grantedMenus, item.menu)).toList(),
              ),
              const SizedBox(height: 16),
              _FeatureSection(
                title: 'Account',
                children: [
                  _FeatureItem(
                    icon: Icons.logout_rounded,
                    title: l10n.t('signOut'),
                    subtitle: l10n.t('signOutDesc'),
                    color: colors.error,
                    destructive: true,
                    onTap: _signOut,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      label: 'Processing...',
    );
  }

  ButtonStyle _segmentStyle() {
    return SegmentedButton.styleFrom(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Color _syncColor(BuildContext context, SyncPhase phase) {
    final colors = Theme.of(context).colorScheme;
    return switch (phase) {
      SyncPhase.failed => colors.error,
      SyncPhase.notSignedIn => colors.tertiary,
      SyncPhase.offline => colors.onSurfaceVariant,
      SyncPhase.syncing => colors.primary,
      SyncPhase.idle => colors.secondary,
    };
  }

  String _syncText(SyncState sync) {
    if (sync.phase == SyncPhase.notSignedIn) {
      return 'Sign in to sync';
    }
    if (sync.phase == SyncPhase.offline) {
      return 'Offline • ${sync.pendingCount} pending';
    }
    if (sync.phase == SyncPhase.failed) {
      return sync.message.isEmpty ? 'Sync failed' : sync.message;
    }
    if (sync.phase == SyncPhase.syncing) return 'Syncing...';
    return sync.message.isEmpty ? '${sync.pendingCount} pending' : sync.message;
  }

  String _themeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'Light mode',
      ThemeMode.dark => 'Dark mode',
      ThemeMode.system => 'System theme',
    };
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
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE8DDD2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.045),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    indent: 70,
                    endIndent: 14,
                    color: Color(0xFFF0EAE2),
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
    this.menu,
    this.onTap,
    this.trailing,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String? menu;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool destructive;
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.item});

  final _FeatureItem item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = item.destructive ? colors.error : item.color;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: item.destructive ? 0.08 : 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(item.icon, color: color, size: 22),
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
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: item.destructive ? colors.error : colors.onSurface,
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
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF8A8A8A),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (item.trailing != null)
                item.trailing!
              else if (item.onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Color(0xFFB8B0A6),
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
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 0.3,
            fontWeight: FontWeight.w900,
            color: colors.onSurface,
          ),
        ),
      ],
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

  String get _syncLabel {
    return switch (sync.phase) {
      SyncPhase.failed => 'Sync failed',
      SyncPhase.notSignedIn => 'Sign in to sync',
      SyncPhase.offline => 'Offline • ${sync.pendingCount}',
      SyncPhase.syncing => 'Syncing',
      SyncPhase.idle => 'Synced',
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusColor = switch (sync.phase) {
      SyncPhase.failed => colors.error,
      SyncPhase.notSignedIn => colors.secondary,
      SyncPhase.offline => colors.onSurfaceVariant,
      SyncPhase.syncing => colors.tertiary,
      SyncPhase.idle => colors.primary,
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary.withValues(alpha: 0.14),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.primary.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const ShopAvatar(radius: 27),
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
                    fontSize: 16.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_done_rounded, size: 14, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  _syncLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
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
