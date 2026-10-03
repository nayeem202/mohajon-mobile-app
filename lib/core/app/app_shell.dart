import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../features/customers/presentation/customer_list_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/pos/presentation/pos_screen.dart';
import '../../features/products/presentation/product_list_screen.dart';
import '../../features/staff/models/menu_codes.dart';
import '../../features/staff/providers/staff_providers.dart';
import '../../features/subscription/services/paywall_service.dart';
import '../../features/voice_assistant/presentation/hambot_sheet.dart';
import '../constants/app_constants.dart';
import '../localization/app_localizations.dart';
import '../widgets/nav_bar/animated_bottom_nav_bar.dart';
import '../widgets/nav_bar/nav_destination.dart';
import 'feature_hub_screen.dart';
import 'app_lock_controller.dart';
import 'app_lock_screen.dart';
import 'app_providers.dart';
import 'tour_models.dart';
import 'tour_overlay.dart';

// Tour keys for More/FeatureHubScreen items
final tourMoreVendorsKey = GlobalKey();
final tourMoreExpensesKey = GlobalKey();
final tourMoreInvestorsKey = GlobalKey();
final tourMoreStaffKey = GlobalKey();
final tourMoreReportsKey = GlobalKey();
final tourMoreInvestmentsKey = GlobalKey();
final tourMoreSettingsKey = GlobalKey();

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  late int _index;
  bool _tourChecked = false;

  // Tour state
  bool _tourActive = false;
  int _tourStepIndex = 0;
  OverlayEntry? _tourOverlay;
  List<TourStep> _tourSteps = [];

  // Nav item keys for the bottom bar
  final List<GlobalKey> _navKeys = List.generate(5, (_) => GlobalKey());

  // Scroll controller for More/FeatureHubScreen during tour
  final ScrollController _moreScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final box = Hive.box(HiveBoxes.settings);
    _index = box.get('selectedTab', defaultValue: 0) as int;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshPaywall();
      if (!_tourChecked && mounted) {
        _tourChecked = true;
        final hasSeenTour = box.get('hasSeenTour', defaultValue: false) as bool;
        if (!hasSeenTour && !_lockRequired()) {
          _startTour();
        }
      }
    });
  }

  void _refreshPaywall() {
    ref
        .read(paywallStateProvider.notifier)
        .refresh(online: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPaywall();
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      if (_lockRequired()) {
        ref.read(appLockProvider.notifier).lock();
      }
    }
  }

  bool _lockRequired() {
    final lock = ref.read(appLockProvider);
    return lock.enabled && !lock.unlocked;
  }

  void _onTabSelected(int index) {
    setState(() => _index = index);
    final box = Hive.box(HiveBoxes.settings);
    box.put('selectedTab', index);
  }

  Future<void> _openHambot() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const HambotSheet(),
    );
  }

  void _startTour() {
    final l10n = AppLocalizations.of(context);
    _tourSteps = [
      TourStep(
        targetKey: _navKeys[0],
        title: l10n.t('tourStepHome'),
        description: l10n.t('tourStepHomeDesc'),
        tabIndex: 0,
      ),
      TourStep(
        targetKey: tourDashboardStatsKey,
        title: l10n.t('tourStepStats'),
        description: l10n.t('tourStepStatsDesc'),
        tabIndex: 0,
      ),
      TourStep(
        targetKey: _navKeys[1],
        title: l10n.t('tourStepSales'),
        description: l10n.t('tourStepSalesDesc'),
        tabIndex: 1,
      ),
      TourStep(
        targetKey: tourProductGridKey,
        title: l10n.t('tourStepProductGrid'),
        description: l10n.t('tourStepProductGridDesc'),
        tabIndex: 1,
      ),
      TourStep(
        targetKey: _navKeys[2],
        title: l10n.t('tourStepStock'),
        description: l10n.t('tourStepStockDesc'),
        tabIndex: 2,
      ),
      TourStep(
        targetKey: tourAddProductKey,
        title: l10n.t('tourStepAddProduct'),
        description: l10n.t('tourStepAddProductDesc'),
        tabIndex: 2,
      ),
      TourStep(
        targetKey: _navKeys[3],
        title: l10n.t('tourStepClients'),
        description: l10n.t('tourStepClientsDesc'),
        tabIndex: 3,
      ),
      TourStep(
        targetKey: tourAddClientKey,
        title: l10n.t('tourStepAddClient'),
        description: l10n.t('tourStepAddClientDesc'),
        tabIndex: 3,
      ),
      TourStep(
        targetKey: _navKeys[4],
        title: l10n.t('tourStepMore'),
        description: l10n.t('tourStepMoreDesc'),
        tabIndex: 4,
      ),
      TourStep(
        targetKey: tourMoreVendorsKey,
        title: l10n.t('tourMoreVendors'),
        description: l10n.t('tourMoreVendorsDesc'),
        tabIndex: 4,
      ),
      TourStep(
        targetKey: tourMoreExpensesKey,
        title: l10n.t('tourMoreExpenses'),
        description: l10n.t('tourMoreExpensesDesc'),
        tabIndex: 4,
      ),
      TourStep(
        targetKey: tourMoreInvestorsKey,
        title: l10n.t('tourMoreInvestors'),
        description: l10n.t('tourMoreInvestorsDesc'),
        tabIndex: 4,
      ),
      TourStep(
        targetKey: tourMoreStaffKey,
        title: l10n.t('tourMoreStaff'),
        description: l10n.t('tourMoreStaffDesc'),
        tabIndex: 4,
      ),
      TourStep(
        targetKey: tourMoreReportsKey,
        title: l10n.t('tourMoreReports'),
        description: l10n.t('tourMoreReportsDesc'),
        tabIndex: 4,
      ),
      TourStep(
        targetKey: tourMoreInvestmentsKey,
        title: l10n.t('tourMoreInvestments'),
        description: l10n.t('tourMoreInvestmentsDesc'),
        tabIndex: 4,
      ),
      TourStep(
        targetKey: tourMoreSettingsKey,
        title: l10n.t('tourMoreSettings'),
        description: l10n.t('tourMoreSettingsDesc'),
        tabIndex: 4,
      ),
    ];
    _tourStepIndex = 0;
    _tourActive = true;
    _showTourOverlay();
  }

  void _showTourOverlay() {
    _tourOverlay?.remove();
    _tourOverlay = OverlayEntry(
      builder: (_) => TourOverlay(
        steps: _tourSteps,
        currentIndex: _tourStepIndex,
        onNext: _tourNext,
        onSkip: _tourSkipAll,
        onFinish: _tourFinish,
      ),
    );
    Overlay.of(context).insert(_tourOverlay!);
  }

  void _tourNext() {
    _tourStepIndex++;
    if (_tourStepIndex >= _tourSteps.length) {
      _tourFinish();
      return;
    }
    final nextStep = _tourSteps[_tourStepIndex];
    void showAfterScroll() {
      _scrollTourTargetIntoView(nextStep).then((_) {
        if (mounted && _tourActive) _showTourOverlay();
      });
    }

    if (nextStep.tabIndex != _index) {
      setState(() => _index = nextStep.tabIndex);
      final box = Hive.box(HiveBoxes.settings);
      box.put('selectedTab', _index);
      // Wait for the new screen to render, then update overlay
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted && _tourActive) showAfterScroll();
        });
      });
    } else {
      showAfterScroll();
    }
  }

  RenderBox? _findTourTargetBox(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final obj = ctx.findRenderObject();
    return (obj is RenderBox && obj.attached) ? obj : null;
  }

  Future<void> _scrollTourTargetIntoView(TourStep step) async {
    if (!_moreScrollController.hasClients || step.tabIndex != 4) return;

    // The nav button itself is not inside the More list — never scroll for it.
    if (identical(step.targetKey, _navKeys[4])) return;

    final desiredScreenY = MediaQuery.of(context).size.height * 0.30;

    // Ensure the target widget is built before measuring (ListView builds lazily).
    RenderBox? box;
    for (var i = 0; i < 8; i++) {
      box = _findTourTargetBox(step.targetKey);
      if (box != null) break;
      // Not built yet; scroll toward an estimated region and retry.
      final extent = _moreScrollController.position.maxScrollExtent;
      final next = _estimatedMoreOffset(step, extent);
      if (next == null) break;
      if ((_moreScrollController.offset - next).abs() < 1) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      } else {
        await _moreScrollController.animateTo(
          next,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    }

    if (box == null) return;

    // Precisely position the target near the top so its tooltip stays visible.
    final targetScreenY = box.localToGlobal(Offset.zero).dy;
    if (targetScreenY > desiredScreenY) {
      final delta = targetScreenY - desiredScreenY;
      final newOffset = (_moreScrollController.offset + delta).clamp(
        0.0,
        _moreScrollController.position.maxScrollExtent,
      );
      await _moreScrollController.animateTo(
        newOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  double? _estimatedMoreOffset(TourStep step, double extent) {
    final keys = [
      tourMoreVendorsKey,
      tourMoreExpensesKey,
      tourMoreInvestorsKey,
      tourMoreStaffKey,
      tourMoreReportsKey,
      tourMoreInvestmentsKey,
      tourMoreSettingsKey,
    ];
    final index = keys.indexWhere((k) => identical(k, step.targetKey));
    if (index < 0) return null;
    // Spread items roughly evenly so early items need little scroll.
    return extent * (index / (keys.length - 1));
  }

  void _tourSkipAll() {
    _tourActive = false;
    _tourOverlay?.remove();
    _tourOverlay = null;
    Hive.box(HiveBoxes.settings).put('hasSeenTour', true);
  }

  void _tourFinish() {
    _tourActive = false;
    _tourOverlay?.remove();
    _tourOverlay = null;
    Hive.box(HiveBoxes.settings).put('hasSeenTour', true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tourOverlay?.remove();
    _moreScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final grantedMenus = ref.watch(myMenuCodesProvider).value;
    final session = ref.watch(authStateProvider).value;
    final isOwner =
        session?.roles.any(
          (role) =>
              role.toUpperCase() == 'OWNER' || role.toUpperCase() == 'ADMIN',
        ) ??
        false;
    final tabs = _buildTabs(l10n, grantedMenus, isOwner);
if (tabs.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.t('noFeaturesAssigned'),
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

    final lock = ref.watch(appLockProvider);
    final shell = ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Scaffold(
        extendBody: !wide,
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  if (wide)
                    _SideNav(
                      selectedIndex: _index,
                      destinations: destinations,
                      onSelected: _onTabSelected,
                      onAsk: _openHambot,
                    ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: child,
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey(_index),
                        child: screens[_index],
                      ),
                    ),
                  ),
                ],
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
                itemKeys: _navKeys,
                trailing: _HambotNavButton(onTap: _openHambot),
              ),
      ),
    );
    if (lock.enabled && !lock.unlocked) {
      return Stack(
        fit: StackFit.expand,
        children: [
          shell,
          Positioned.fill(child: _LockScreen(l10n: l10n)),
        ],
      );
    }
    return shell;
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
          _Tab(
            destination: NavDestination(
              icon: Icons.more_horiz_rounded,
              label: l10n.t('more'),
            ),
            screen: FeatureHubScreen(
              tourVendorsKey: tourMoreVendorsKey,
              tourExpensesKey: tourMoreExpensesKey,
              tourInvestorsKey: tourMoreInvestorsKey,
              tourStaffKey: tourMoreStaffKey,
              tourReportsKey: tourMoreReportsKey,
              tourInvestmentsKey: tourMoreInvestmentsKey,
              tourSettingsKey: tourMoreSettingsKey,
              scrollController: _moreScrollController,
            ),
            menu: null,
          ),
        ]
        .where((tab) => hasMenuAccess(grantedMenus, tab.menu, isOwner: isOwner))
        .toList();
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
    required this.onAsk,
  });

  final int selectedIndex;
  final List<NavDestination> destinations;
  final ValueChanged<int> onSelected;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: 244,
      margin: const EdgeInsets.all(18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7D6),
        border: Border.all(color: const Color(0xFFF0DF9A)),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2F3028).withValues(alpha: 0.14),
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
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFC800), Color(0xFFFFE36E)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Stack(
                    children: [
                      const Center(
                        child: Icon(
                          Icons.receipt_long_rounded,
                          color: Color(0xFF2F3028),
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
                            color: Color(0xFF2F3028),
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
                          color: Color(0xFF2F3028),
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        AppConstants.appTagline,
                        style: TextStyle(
                          color: Color(0xFF77735F),
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
          const SizedBox(height: 8),
          _SideNavItem(
            destination: NavDestination(
              icon: Icons.auto_awesome_rounded,
              label: l10n.t('hambotQuickAsk'),
            ),
            selected: false,
            onTap: onAsk,
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0A6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.cloud_done_rounded, color: Color(0xFF2F3028)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.t('offlineFirstCloud'),
                    style: const TextStyle(
                      color: Color(0xFF5D5B45),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFFC800) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: selected
                ? Border.all(color: Colors.white.withValues(alpha: 0.22))
                : null,
          ),
          child: Row(
            children: [
              Icon(
                destination.icon,
                color: selected
                    ? const Color(0xFF2F3028)
                    : const Color(0xFF77735F),
              ),
              const SizedBox(width: 12),
              Text(
                destination.label,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF2F3028)
                      : const Color(0xFF5D5B45),
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

class _HambotNavButton extends StatelessWidget {
  const _HambotNavButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).t('hambotQuickAsk'),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFC800), Color(0xFFFFE36E)],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.40),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFC800).withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFF2F3028),
                size: 19,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LockScreen extends ConsumerWidget {
  const _LockScreen({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppLockScreen(
      title: l10n.t('enterPinTitle'),
      subtitle: l10n.t('unlockAppSubtitle'),
      autoPopOnSuccess: false,
      lockoutRemaining: () =>
          ref.read(appLockProvider.notifier).lockoutRemaining,
      onSubmit: (pin) async {
        final notifier = ref.read(appLockProvider.notifier);
        if (notifier.verify(pin)) {
          notifier.unlock();
          return true;
        }
        return false;
      },
    );
  }
}
