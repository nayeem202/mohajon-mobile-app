import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_error.dart';

import '../../../core/models/customer.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/snackbar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/nav_bar/nav_bar_aware_fab_location.dart';
import '../../payments/presentation/add_payment_screen.dart';
import 'customer_profile_screen.dart';
import '../providers/customer_providers.dart';
import 'customer_form_screen.dart';
import '../../pos/presentation/sales_history_screen.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';

final GlobalKey tourAddClientKey = GlobalKey();

enum _ClientFilter { all, dues, vip, recent }
enum _ClientSort { lastVisit, name, totalSpent, dues }

class _CustomerSummary {
  const _CustomerSummary({
    this.totalSpent = 0,
    this.visitCount = 0,
    this.lastVisit,
  });

  final double totalSpent;
  final int visitCount;
  final DateTime? lastVisit;

  bool get hasData => totalSpent > 0 || visitCount > 0 || lastVisit != null;
}

class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  late final TextEditingController _searchController;
  _ClientFilter _filter = _ClientFilter.all;
  _ClientSort _sort = _ClientSort.lastVisit;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final customersAsync = ref.watch(customersProvider);
    final searchQuery = ref.watch(customerSearchQueryProvider);
    final sales = ref.watch(salesStreamProvider).value ?? const <dynamic>[];

    return Theme(
      data: MohajonWarm.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: MohajonWarm.pageGradient),
          child: SafeArea(
            child: customersAsync.when(
              data: (items) {
                final customerStats = <String, _CustomerSummary>{};
                for (final customer in items) {
                  final customerSales = sales
                      .where((sale) => sale.customerId == customer.customerId)
                      .toList();
                  final totalSpent = customerSales.fold<double>(
                    0,
                    (sum, sale) => sum + sale.totalAmount,
                  );
                  final lastVisit = customerSales.isEmpty
                      ? null
                      : customerSales
                            .map((sale) => sale.createdAt)
                            .reduce((a, b) => a.isAfter(b) ? a : b);
                  customerStats[customer.customerId] = _CustomerSummary(
                    totalSpent: totalSpent,
                    visitCount: customerSales.length,
                    lastVisit: lastVisit,
                  );
                }
                final dueByCustomer = {
                  for (final customer in items)
                    customer.customerId: ref.watch(
                      customerDueProvider(customer.customerId),
                    ),
                };
                final filteredItems = _applyFilter(
                  ref.watch(filteredCustomersProvider),
                  dueByCustomer,
                  customerStats,
                );
                final totalDue = dueByCustomer.values.fold<double>(
                  0,
                  (sum, value) => sum + (value > 0 ? value : 0),
                );
                final dueCount = dueByCustomer.values
                    .where((due) => due > 0)
                    .length;

                return RefreshIndicator(
                  color: MohajonWarm.goldText,
                  onRefresh: () async {
                    await ref.read(customersProvider.future);
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 96),
                    children: [
                      const _ClientsTopBar(),
                      const SizedBox(height: 18),
                      _ClientStats(
                        totalClients: items.length,
                        dueClients: dueCount,
                        totalReceivable: totalDue,
                      ),
                      if (_showSearch) ...[
                        const SizedBox(height: 16),
                        _SearchAndFilters(
                          controller: _searchController,
                          searchQuery: searchQuery,
                          selectedFilter: _filter,
                          selectedSort: _sort,
                          onSearchChanged: (value) =>
                              ref.read(customerSearchQueryProvider.notifier).state =
                                  value,
                          onClearSearch: () {
                            _searchController.clear();
                            ref.read(customerSearchQueryProvider.notifier).state =
                                '';
                          },
                          onFilterChanged: (filter) =>
                              setState(() => _filter = filter),
                          onSortChanged: (sort) => setState(() => _sort = sort),
                        ),
                      ],
                      const SizedBox(height: 18),
                      _SectionTitle(count: filteredItems.length),
                      const SizedBox(height: 12),
                      if (items.isEmpty)
                        EmptyState(
                          message: l10n.t('addClientsToTrack'),
                          icon: Icons.people_alt_outlined,
                        )
                      else if (filteredItems.isEmpty)
                        EmptyState(
                          message: l10n.t('noClientsMatch'),
                          icon: Icons.search_off_rounded,
                        )
                      else
                        _ClientList(
                          customers: filteredItems,
                          dueByCustomer: dueByCustomer,
                          customerStats: customerStats,
                          onCustomerTap: (customer) => _showCustomerSheet(
                            context,
                            customer: customer,
                            due: dueByCustomer[customer.customerId] ?? 0,
                            stats: customerStats[customer.customerId] ??
                                const _CustomerSummary(),
                          ),
                        ),
                    ],
                  ),
                );
              },
              error: (error, _) => EmptyState(
                  message: friendlyErrorMessage(error,
                      fallback: l10n.t('couldNotLoadClients')),
                ),
              loading: () => const Center(
                child: CircularProgressIndicator(color: MohajonWarm.primary),
              ),
            ),
          ),
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.small(
              heroTag: 'search',
              onPressed: () {
                setState(() => _showSearch = !_showSearch);
                if (!_showSearch) {
                  _searchController.clear();
                  ref.read(customerSearchQueryProvider.notifier).state = '';
                }
              },
              child: Icon(
                _showSearch ? Icons.search_off_rounded : Icons.search_rounded,
                size: 22,
              ),
            ),
            const SizedBox(height: 8),
            KeyedSubtree(
              key: tourAddClientKey,
              child: FloatingActionButton(
                heroTag: 'add',
                onPressed: _openAddClient,
                child: const Icon(Icons.add_rounded, size: 26),
              ),
            ),
          ],
        ),
        floatingActionButtonLocation: const NavBarAwareFabLocation(),
      ),
    );
  }

  List<Customer> _applyFilter(
    List<Customer> customers,
    Map<String, double> dueByCustomer,
    Map<String, _CustomerSummary> customerStats,
  ) {
    final sorted = [...customers]
      ..sort((a, b) {
        return switch (_sort) {
          _ClientSort.lastVisit => (customerStats[b.customerId]?.lastVisit ??
                  DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(
                customerStats[a.customerId]?.lastVisit ??
                    DateTime.fromMillisecondsSinceEpoch(0),
              ),
          _ClientSort.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          _ClientSort.totalSpent => (customerStats[b.customerId]?.totalSpent ?? 0)
              .compareTo(customerStats[a.customerId]?.totalSpent ?? 0),
          _ClientSort.dues => (dueByCustomer[b.customerId] ?? 0)
              .compareTo(dueByCustomer[a.customerId] ?? 0),
        };
      });
    return switch (_filter) {
      _ClientFilter.all => sorted,
      _ClientFilter.dues =>
        sorted
            .where((customer) => (dueByCustomer[customer.customerId] ?? 0) > 0)
            .toList(),
      _ClientFilter.vip => sorted.take(8).toList(),
      _ClientFilter.recent => sorted,
    };
  }

  void _openAddClient() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CustomerFormScreen()));
  }

  Future<void> _showCustomerSheet(
    BuildContext context, {
    required Customer customer,
    required double due,
    required _CustomerSummary stats,
  }) {
    final l10n = AppLocalizations.of(context);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _CustomerDetailSheet(
          customer: customer,
          due: due,
          stats: stats,
          onCall: () {
            Navigator.of(sheetContext).pop();
            showAppSnackBar(context, '${l10n.t('call')} ${customer.phone}');
          },
          onViewProfile: () {
            Navigator.of(sheetContext).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CustomerProfileScreen(customer: customer),
              ),
            );
          },
          onViewInvoices: () {
            Navigator.of(sheetContext).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SalesHistoryScreen(customer: customer),
              ),
            );
          },
          onRecordPayment: () {
            Navigator.of(sheetContext).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AddPaymentScreen(customer: customer),
              ),
            );
          },
        );
      },
    );
  }
}

class _ClientsTopBar extends StatelessWidget {
  const _ClientsTopBar();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IconTheme(
      data: const IconThemeData(color: MohajonWarm.ink),
      child: Row(
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
              Icons.groups_rounded,
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
                  l10n.t('clients'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: MohajonWarm.ink,
                  ),
                ),
                Text(
                  l10n.t('customersDueLedger'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF77735F),
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
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.t('allClients'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
              color: MohajonWarm.ink,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: MohajonWarm.primary.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: MohajonWarm.primary.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            l10n.tP('clientsCount', {'n': '$count'}),
            style: const TextStyle(
              color: Color(0xFF5D4A00),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _ClientStats extends StatelessWidget {
  const _ClientStats({
    required this.totalClients,
    required this.dueClients,
    required this.totalReceivable,
  });

  final int totalClients;
  final int dueClients;
  final double totalReceivable;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cards = [
      _StatSpec(
        icon: Icons.people_alt_rounded,
        label: l10n.t('totalClients'),
        value: '$totalClients',
        subtext: l10n.t('allClientsShort'),
        color: MohajonWarm.goldText,
        background: MohajonWarm.tintYellow,
      ),
      _StatSpec(
        icon: Icons.error_outline_rounded,
        label: l10n.t('withDuesStat'),
        value: '$dueClients',
        subtext: l10n.t('followUp'),
        color: MohajonWarm.red,
        background: MohajonWarm.tintRed,
      ),
    ];

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isSingleColumn = constraints.maxWidth < 320;
            final cardWidth = isSingleColumn
                ? constraints.maxWidth
                : (constraints.maxWidth - 12) / 2;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final card in cards)
                  SizedBox(width: cardWidth, child: _StatCard(spec: card)),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _ReceivableCard(
          value: money(totalReceivable),
          dueClients: dueClients,
        ),
      ],
    );
  }
}

class _StatSpec {
  const _StatSpec({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtext,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final String label;
  final String value;
  final String subtext;
  final Color color;
  final Color background;
}

/// Matches the Home / Stock screen stat card styling.
class _StatCard extends StatelessWidget {
  const _StatCard({required this.spec});

  final _StatSpec spec;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 130,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [spec.background, MohajonWarm.card],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MohajonWarm.goldBorder),
        boxShadow: [
          BoxShadow(
            color: spec.color.withValues(alpha: 0.09),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: spec.color.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(spec.icon, color: spec.color, size: 16),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: spec.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    spec.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: spec.color,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              spec.value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 20,
                color: colors.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            spec.subtext,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceivableCard extends StatelessWidget {
  const _ReceivableCard({required this.value, required this.dueClients});

  final String value;
  final int dueClients;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MohajonWarm.tintGreen, MohajonWarm.card],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MohajonWarm.goldBorder),
        boxShadow: [
          BoxShadow(
            color: MohajonWarm.green.withValues(alpha: 0.09),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: MohajonWarm.green.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.payments_rounded,
              color: MohajonWarm.green,
              size: 19,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      l10n.t('totalReceivable'),
                      style: const TextStyle(
                        color: MohajonWarm.green,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        l10n.tP('acrossClients', {'n': '$dueClients'}),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 22,
                      color: colors.onSurface,
                      fontWeight: FontWeight.w900,
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

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.controller,
    required this.searchQuery,
    required this.selectedFilter,
    required this.selectedSort,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onFilterChanged,
    required this.onSortChanged,
  });

  final TextEditingController controller;
  final String searchQuery;
  final _ClientFilter selectedFilter;
  final _ClientSort selectedSort;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<_ClientFilter> onFilterChanged;
  final ValueChanged<_ClientSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MohajonWarm.card,
        border: Border.all(color: MohajonWarm.goldBorder),
        borderRadius: BorderRadius.circular(20),
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
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: TextField(
                    controller: controller,
                    onChanged: onSearchChanged,
                    decoration: InputDecoration(
                      hintText: l10n.t('searchByNamePhone'),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: MohajonWarm.muted,
                      ),
                      suffixIcon: searchQuery.isEmpty
                          ? null
                          : IconButton(
                              onPressed: onClearSearch,
                              icon: const Icon(
                                Icons.clear_rounded,
                                color: MohajonWarm.muted,
                              ),
                            ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              DropdownButtonHideUnderline(
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: MohajonWarm.goldBorder),
                  ),
                  child: DropdownButton<_ClientSort>(
                    value: selectedSort,
                    borderRadius: BorderRadius.circular(14),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: MohajonWarm.muted,
                    ),
                    style: const TextStyle(
                      color: MohajonWarm.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: _ClientSort.lastVisit,
                        child: Text(l10n.t('lastVisit')),
                      ),
                      DropdownMenuItem(
                        value: _ClientSort.name,
                        child: Text(l10n.t('name')),
                      ),
                      DropdownMenuItem(
                        value: _ClientSort.totalSpent,
                        child: Text(l10n.t('totalSpent')),
                      ),
                      DropdownMenuItem(
                        value: _ClientSort.dues,
                        child: Text(l10n.t('due')),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) onSortChanged(value);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: l10n.t('allClients'),
                  selected: selectedFilter == _ClientFilter.all,
                  onTap: () => onFilterChanged(_ClientFilter.all),
                ),
                _FilterChip(
                  label: l10n.t('withDuesStat'),
                  selected: selectedFilter == _ClientFilter.dues,
                  onTap: () => onFilterChanged(_ClientFilter.dues),
                ),
                _FilterChip(
                  label: l10n.t('vip'),
                  selected: selectedFilter == _ClientFilter.vip,
                  onTap: () => onFilterChanged(_ClientFilter.vip),
                ),
                _FilterChip(
                  label: l10n.t('recent'),
                  selected: selectedFilter == _ClientFilter.recent,
                  onTap: () => onFilterChanged(_ClientFilter.recent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? MohajonWarm.primary : Colors.white,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? MohajonWarm.primary.withValues(alpha: 0.45)
                    : MohajonWarm.goldBorder,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFF5D4A00) : MohajonWarm.muted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClientList extends StatelessWidget {
  const _ClientList({
    required this.customers,
    required this.dueByCustomer,
    required this.customerStats,
    required this.onCustomerTap,
  });

  final List<Customer> customers;
  final Map<String, double> dueByCustomer;
  final Map<String, _CustomerSummary> customerStats;
  final ValueChanged<Customer> onCustomerTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < customers.length; index++) ...[
          if (index != 0) const SizedBox(height: 10),
          _ClientRow(
            customer: customers[index],
            due: dueByCustomer[customers[index].customerId] ?? 0,
            stats: customerStats[customers[index].customerId] ??
                const _CustomerSummary(),
            onTap: () => onCustomerTap(customers[index]),
          ),
        ],
      ],
    );
  }
}

class _ClientRow extends StatelessWidget {
  const _ClientRow({
    required this.customer,
    required this.due,
    required this.stats,
    required this.onTap,
  });

  final Customer customer;
  final double due;
  final _CustomerSummary stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasDue = due > 0;

    final leading = _RoundAvatar(
      size: 46,
      initials: _initials(customer.name),
      imagePath: customer.imagePath,
      danger: hasDue,
    );

    return Material(
      color: MohajonWarm.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: MohajonWarm.goldBorder),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: MohajonWarm.ink.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            customer.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: MohajonWarm.ink,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(child: Consumer(
                          builder: (context, ref, _) {
                            final tag = ref.watch(
                              customerTagProvider(customer.customerId),
                            );
                            final displayTag = tag.isNotEmpty
                                ? tag
                                : (hasDue ? l10n.t('hasDues') : '');
                            if (displayTag.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            final tagColor = displayTag == 'VIP'
                                ? MohajonWarm.goldText
                                : displayTag == l10n.t('hasDues')
                                    ? MohajonWarm.red
                                    : MohajonWarm.green;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: tagColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                displayTag,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: TextStyle(
                                  color: tagColor,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            );
                          },
                        )),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      customer.phone.isEmpty
                          ? l10n.t('noPhoneNumber')
                          : customer.phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MohajonWarm.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    money(stats.totalSpent),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: MohajonWarm.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: hasDue
                          ? MohajonWarm.tintRed
                          : MohajonWarm.tintGreen,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      hasDue ? l10n.tP('dueAmount', {'amount': money(due)}) : l10n.t('clear'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasDue ? MohajonWarm.red : MohajonWarm.green,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    stats.lastVisit == null
                        ? 'No visits yet'
                        : '${stats.visitCount} visits · ${_formatRelativeDay(stats.lastVisit!)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: MohajonWarm.muted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty);
  if (parts.isEmpty) return 'CL';
  final value = parts.take(2).map((part) => part[0].toUpperCase()).join();
  return value.length == 1 ? '${value}U' : value;
}

String _formatRelativeDay(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inHours < 24) return 'Today';
  if (diff.inHours < 48) return 'Yesterday';
  return '${diff.inDays} days ago';
}

class _CustomerDetailSheet extends ConsumerWidget {
  const _CustomerDetailSheet({
    required this.customer,
    required this.due,
    required this.stats,
    required this.onCall,
    required this.onViewProfile,
    required this.onViewInvoices,
    required this.onRecordPayment,
  });

  final Customer customer;
  final double due;
  final _CustomerSummary stats;
  final VoidCallback onCall;
  final VoidCallback onViewProfile;
  final VoidCallback onViewInvoices;
  final VoidCallback onRecordPayment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final initials = _initials(customer.name);
    final tag = ref.watch(customerTagProvider(customer.customerId));
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.72,
      maxChildSize: 0.97,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: MohajonWarm.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: MohajonWarm.goldBorder,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _RoundAvatar(
                      size: 58,
                      initials: initials,
                      imagePath: customer.imagePath,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: MohajonWarm.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (tag.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: tag == 'VIP'
                                    ? MohajonWarm.tintYellow
                                    : MohajonWarm.tintGreen,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: MohajonWarm.goldBorder),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  color: tag == 'VIP'
                                      ? MohajonWarm.goldText
                                      : MohajonWarm.green,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: MohajonWarm.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryTile(
                        title: 'Total Spent',
                        value: money(stats.totalSpent),
                        valueColor: MohajonWarm.ink,
                        background: MohajonWarm.tintYellow,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryTile(
                        title: l10n.t('outstandingDues'),
                        value: due > 0 ? money(due) : l10n.t('allClear'),
                        valueColor: due > 0
                            ? MohajonWarm.red
                            : MohajonWarm.green,
                        background: due > 0
                            ? MohajonWarm.tintRed
                            : MohajonWarm.tintGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: MohajonWarm.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: MohajonWarm.goldBorder),
                  ),
                  child: Column(
                    children: [
                      _InfoLine(
                        icon: Icons.phone_outlined,
                        text: customer.phone.isEmpty
                            ? l10n.t('noPhoneAdded')
                            : customer.phone,
                      ),
                      _InfoLine(
                        icon: Icons.email_outlined,
                        text: customer.email.isEmpty
                            ? l10n.t('noEmailAdded')
                            : customer.email,
                      ),
                      _InfoLine(
                        icon: Icons.location_on_outlined,
                        text: customer.address.isEmpty
                            ? l10n.t('noAddressSaved')
                            : customer.address,
                      ),
                      _InfoLine(
                        icon: Icons.calendar_month_outlined,
                        text: stats.lastVisit == null
                            ? l10n.t('lastVisitNoVisits')
                            : l10n.tP('lastVisitTime', {
                                'time': _formatRelativeDay(stats.lastVisit!),
                              }),
                      ),
                      _InfoLine(
                        icon: Icons.history_outlined,
                        text: l10n.tP('totalVisits', {
                          'n': '${stats.visitCount}',
                        }),
                        showDivider: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: MohajonWarm.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: MohajonWarm.goldBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.t('notes'),
                        style: const TextStyle(
                          color: MohajonWarm.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        customer.notes.isEmpty
                            ? l10n.t('noNotesForClient')
                            : customer.notes,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: MohajonWarm.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  CustomerFormScreen(customer: customer),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(l10n.t('profile')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onViewInvoices,
                        icon: const Icon(Icons.receipt_long_rounded),
                        label: Text(l10n.t('invoices')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: MohajonWarm.primary,
                          foregroundColor: MohajonWarm.ink,
                        ),
                        onPressed: onCall,
                        icon: const Icon(Icons.call_rounded),
                        label: Text(l10n.t('call')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: MohajonWarm.green,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: onRecordPayment,
                        icon: const Icon(Icons.payments_outlined),
                        label: Text(l10n.t('recordPayment')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Round avatar matching the Investors list: warm gradient, white ring,
/// soft glow, initials fallback (red tint when the client has dues).
class _RoundAvatar extends StatelessWidget {
  const _RoundAvatar({
    required this.size,
    required this.initials,
    this.imagePath,
    this.danger = false,
  });

  final double size;
  final String initials;
  final String? imagePath;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final glow = danger ? const Color(0xFFDC2626) : const Color(0xFFE98300);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(
        child: imagePath != null
            ? AppImage.file(
                File(imagePath!),
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(glow),
              )
            : _fallback(glow),
      ),
    );
  }

  Widget _fallback(Color glow) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE9CF), Color(0xFFFCD9AE)],
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: glow,
            fontSize: size * 0.34,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.title,
    required this.value,
    required this.valueColor,
    required this.background,
  });

  final String title;
  final String value;
  final Color valueColor;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MohajonWarm.goldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: MohajonWarm.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.text,
    this.showDivider = true,
  });

  final IconData icon;
  final String text;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 18, color: MohajonWarm.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MohajonWarm.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 14, endIndent: 14),
      ],
    );
  }
}
