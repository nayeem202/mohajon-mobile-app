import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/customers/presentation/customer_list_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/investments/presentation/investment_dashboard_screen.dart';
import '../../features/pos/presentation/pos_screen.dart';
import '../../features/pos/presentation/sales_history_screen.dart';
import '../../features/products/presentation/product_list_screen.dart';
import '../../features/investors/presentation/investor_list_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/vendors/presentation/vendor_list_screen.dart';
import '../constants/app_constants.dart';
import '../localization/app_localizations.dart';
import '../../features/settings/providers/shop_profile_providers.dart';
import 'feature_hub_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final shopName = ref.watch(shopProfileProvider).value?.shopName ?? '';
    final l10n = AppLocalizations.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final screens = [
      const DashboardScreen(),
      const PosScreen(),
      const ProductListScreen(),
      const CustomerListScreen(),
      const FeatureHubScreen(),
    ];
    final destinations = [
      _Destination(icon: Icons.home_rounded, label: l10n.t('home')),
      _Destination(icon: Icons.shopping_cart_rounded, label: l10n.t('pos')),
      _Destination(icon: Icons.inventory_2_rounded, label: l10n.t('stock')),
      _Destination(icon: Icons.people_alt_rounded, label: l10n.t('clients')),
      _Destination(icon: Icons.more_horiz_rounded, label: l10n.t('more')),
    ];

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Row(
          children: [
            if (wide)
              _SideNav(
                selectedIndex: _index,
                destinations: destinations,
                onSelected: (value) => setState(() => _index = value),
                onMoreTap: () => _showMoreOptions(context),
              ),
            Expanded(child: screens[_index]),
          ],
        ),
        bottomNavigationBar: wide
            ? null
            : _MobileBottomNav(
                selectedIndex: _index,
                destinations: destinations,
                onSelected: (value) => setState(() => _index = value),
                onMoreTap: () => _showMoreOptions(context),
              ),
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _MoreOptionsSheet(
          onSalesHistory: () => _openFromSheet(
            context: context,
            sheetContext: sheetContext,
            screen: const SalesHistoryScreen(),
          ),
          onInvestors: () => _openFromSheet(
            context: context,
            sheetContext: sheetContext,
            screen: const InvestorListScreen(),
          ),
          onVendors: () => _openFromSheet(
            context: context,
            sheetContext: sheetContext,
            screen: const VendorListScreen(),
          ),
          onInvestments: () => _openFromSheet(
            context: context,
            sheetContext: sheetContext,
            screen: const InvestmentDashboardScreen(),
          ),
          onReports: () => _openFromSheet(
            context: context,
            sheetContext: sheetContext,
            screen: const ReportsScreen(),
          ),
          onSettings: () => _openFromSheet(
            context: context,
            sheetContext: sheetContext,
            screen: const SettingsScreen(),
          ),
        );
      },
    );
  }

  void _openFromSheet({
    required BuildContext context,
    required BuildContext sheetContext,
    required Widget screen,
  }) {
    Navigator.of(sheetContext).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _Destination {
  const _Destination({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _SideNav extends StatelessWidget {
  const _SideNav({
    required this.selectedIndex,
    required this.destinations,
    required this.onSelected,
    required this.onMoreTap,
  });

  final int selectedIndex;
  final List<_Destination> destinations;
  final ValueChanged<int> onSelected;
  final VoidCallback onMoreTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 244,
      margin: const EdgeInsets.all(18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 18),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE98300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    children: [
                      const Center(
                        child: Icon(
                          Icons.receipt_long_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      Positioned(
                        right: 7,
                        top: 7,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0F766E),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppConstants.appName,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        AppConstants.appTagline,
                        style: TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (var index = 0; index < destinations.length; index++)
            _SideNavItem(
              destination: destinations[index],
              selected: selectedIndex == index,
              onTap: index == destinations.length - 1
                  ? onMoreTap
                  : () => onSelected(index),
            ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.cloud_done_rounded, color: colors.primary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Offline first, Firebase ready',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
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

class _SideNavItem extends StatelessWidget {
  const _SideNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? colors.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: selected
                ? Border.all(color: colors.primary.withValues(alpha: 0.22))
                : null,
          ),
          child: Row(
            children: [
              Icon(
                destination.icon,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Text(
                destination.label,
                style: TextStyle(
                  color: selected ? colors.primary : colors.onSurface,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileBottomNav extends StatelessWidget {
  const _MobileBottomNav({
    required this.selectedIndex,
    required this.destinations,
    required this.onSelected,
    required this.onMoreTap,
  });

  final int selectedIndex;
  final List<_Destination> destinations;
  final ValueChanged<int> onSelected;
  final VoidCallback onMoreTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: colors.outlineVariant)),
        ),
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
        child: Row(
          children: [
            for (var index = 0; index < destinations.length; index++)
              Expanded(
                child: _BottomNavItem(
                  destination: destinations[index],
                  selected: selectedIndex == index,
                  onTap: index == destinations.length - 1
                      ? onMoreTap
                      : () => onSelected(index),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MoreOptionsSheet extends StatelessWidget {
  const _MoreOptionsSheet({
    required this.onSalesHistory,
    required this.onInvestors,
    required this.onVendors,
    required this.onInvestments,
    required this.onReports,
    required this.onSettings,
  });

  final VoidCallback onSalesHistory;
  final VoidCallback onInvestors;
  final VoidCallback onVendors;
  final VoidCallback onInvestments;
  final VoidCallback onReports;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'MORE OPTIONS',
                    style: TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.62,
                  children: [
                    _MoreOptionTile(
                      label: 'Sales History',
                      icon: Icons.history_rounded,
                      color: const Color(0xFF0F766E),
                      onTap: onSalesHistory,
                    ),
                    _MoreOptionTile(
                      label: 'Investors',
                      icon: Icons.people_alt_rounded,
                      color: const Color(0xFF047857),
                      onTap: onInvestors,
                    ),
                    _MoreOptionTile(
                      label: 'Vendors',
                      icon: Icons.store_rounded,
                      color: const Color(0xFF7C3AED),
                      onTap: onVendors,
                    ),
                    _MoreOptionTile(
                      label: 'Investments',
                      icon: Icons.account_balance_rounded,
                      color: const Color(0xFF0F766E),
                      onTap: onInvestments,
                    ),
                    _MoreOptionTile(
                      label: 'Reports',
                      icon: Icons.pie_chart_outline_rounded,
                      color: const Color(0xFFF97316),
                      onTap: onReports,
                    ),
                    _MoreOptionTile(
                      label: 'Settings',
                      icon: Icons.settings_outlined,
                      color: const Color(0xFF98A2B3),
                      onTap: onSettings,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreOptionTile extends StatelessWidget {
  const _MoreOptionTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFCFBF8),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFECE7DF)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF101828),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = const Color(0xFFF97316);
    final inactive = const Color(0xFF98A2B3);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: selected
                    ? active.withValues(alpha: 0.18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                destination.icon,
                color: selected ? active : inactive,
                size: 22,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? active : inactive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
