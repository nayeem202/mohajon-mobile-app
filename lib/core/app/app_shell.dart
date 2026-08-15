import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../features/customers/presentation/customer_list_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/pos/presentation/pos_screen.dart';
import '../../features/products/presentation/product_list_screen.dart';
import '../../features/staff/models/menu_codes.dart';
import '../../features/staff/providers/staff_providers.dart';
import '../constants/app_constants.dart';
import '../localization/app_localizations.dart';
import '../widgets/nav_bar/animated_bottom_nav_bar.dart';
import '../widgets/nav_bar/nav_destination.dart';
import 'feature_hub_screen.dart';
import 'app_providers.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late int _index;

  @override
  void initState() {
    super.initState();
    final box = Hive.box(HiveBoxes.settings);
    _index = box.get('selectedTab', defaultValue: 0) as int;
  }

  void _onTabSelected(int index) {
    setState(() => _index = index);
    final box = Hive.box(HiveBoxes.settings);
    box.put('selectedTab', index);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final grantedMenus = ref.watch(myMenuCodesProvider).value;
    final session = ref.watch(authStateProvider).value;
    final isOwner = session?.roles.any(
          (role) => role.toUpperCase() == 'OWNER' || role.toUpperCase() == 'ADMIN',
        ) ?? false;
    final tabs = _buildTabs(l10n, grantedMenus, isOwner);
    if (tabs.isEmpty) {
      return const Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No app features have been assigned to this account.\nPlease contact the shop owner.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }
    final screens = [for (final tab in tabs) tab.screen];
    final destinations = [for (final tab in tabs) tab.destination];
    if (_index >= screens.length) {
      _index = screens.length - 1;
    }

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Scaffold(
        extendBody: !wide,
        backgroundColor: Colors.transparent,
        body: Row(
          children: [
            if (wide)
              _SideNav(
                selectedIndex: _index,
                destinations: destinations,
                onSelected: _onTabSelected,
              ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: KeyedSubtree(
                  key: ValueKey(_index),
                  child: screens[_index],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: wide || destinations.length <= 1
            ? null
            : AnimatedBottomNavBar(
                selectedIndex: _index,
                destinations: destinations,
                onSelected: _onTabSelected,
              ),
      ),
    );
  }

  List<_Tab> _buildTabs(
    AppLocalizations l10n,
    List<String>? grantedMenus,
    bool isOwner,
  ) {
    return [
      _Tab(
        destination: NavDestination(
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
          label: l10n.t('home'),
        ),
        screen: const DashboardScreen(),
        menu: MenuCodes.home,
      ),
      _Tab(
        destination: NavDestination(
          icon: Icons.shopping_cart_outlined,
          selectedIcon: Icons.shopping_cart_rounded,
          label: l10n.t('sales'),
        ),
        screen: const PosScreen(),
        menu: MenuCodes.sales,
      ),
      _Tab(
        destination: NavDestination(
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2_rounded,
          label: l10n.t('stock'),
        ),
        screen: const ProductListScreen(),
        menu: MenuCodes.stock,
      ),
      _Tab(
        destination: NavDestination(
          icon: Icons.group_outlined,
          selectedIcon: Icons.group_rounded,
          label: l10n.t('clients'),
        ),
        screen: const CustomerListScreen(),
        menu: MenuCodes.clients,
      ),
      const _Tab(
        destination: NavDestination(icon: Icons.more_horiz_rounded, label: 'More'),
        screen: FeatureHubScreen(),
        menu: null,
      ),
    ].where((tab) => hasMenuAccess(grantedMenus, tab.menu, isOwner: isOwner)).toList();
  }
}

class _Tab {
  const _Tab({
    required this.destination,
    required this.screen,
    required this.menu,
  });

  final NavDestination destination;
  final Widget screen;
  final String? menu;
}

class _SideNav extends StatelessWidget {
  const _SideNav({
    required this.selectedIndex,
    required this.destinations,
    required this.onSelected,
  });

  final int selectedIndex;
  final List<NavDestination> destinations;
  final ValueChanged<int> onSelected;

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
              onTap: () => onSelected(index),
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
                    'Offline first, cloud ready',
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

  final NavDestination destination;
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
