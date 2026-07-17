import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/customer.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../payments/presentation/add_payment_screen.dart';
import 'customer_profile_screen.dart';
import '../providers/customer_providers.dart';
import 'customer_form_screen.dart';
import '../../pos/presentation/sales_history_screen.dart';

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
    final customers = ref.watch(customersProvider);
    final searchQuery = ref.watch(customerSearchQueryProvider);
    final sales = ref.watch(salesStreamProvider).value ?? const <dynamic>[];

    return Scaffold(
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
            child: Icon(_showSearch ? Icons.close : Icons.search_rounded),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'add',
            onPressed: _openAddClient,
            child: const Icon(Icons.add_rounded, size: 28),
          ),
        ],
      ),
      body: SafeArea(
        child: customers.when(
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
            final totalSpent = customerStats.values.fold<double>(
              0,
              (sum, stat) => sum + stat.totalSpent,
            );

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              children: [
                _ClientsTopBar(),
                const SizedBox(height: 18),
                _ClientStats(
                  totalClients: items.length,
                  dueClients: dueCount,
                  totalReceivable: totalDue,
                  totalSpent: totalSpent,
                ),
                if (_showSearch) ...[
                  const SizedBox(height: 18),
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
                      ref.read(customerSearchQueryProvider.notifier).state = '';
                    },
                    onFilterChanged: (filter) => setState(() => _filter = filter),
                    onSortChanged: (sort) => setState(() => _sort = sort),
                  ),
                ],
                const SizedBox(height: 18),
                if (items.isEmpty)
                  const EmptyState(
                    message: 'Add clients to track due payments.',
                    icon: Icons.people_alt_outlined,
                  )
                else if (filteredItems.isEmpty)
                  const EmptyState(
                    message: 'No clients match your search.',
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
            );
          },
          error: (error, _) => EmptyState(message: error.toString()),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Call ${customer.phone}')),
            );
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
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFFE98300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.storefront_rounded,
            color: Colors.white,
            size: 17,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Clients',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF101828),
            ),
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(Icons.notifications_none_rounded, color: colors.onSurface),
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFD6F2EA),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            'KA',
            style: TextStyle(
              color: Color(0xFF0F766E),
              fontWeight: FontWeight.w900,
              fontSize: 12,
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
    required this.totalSpent,
  });

  final int totalClients;
  final int dueClients;
  final double totalReceivable;
  final double totalSpent;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _ClientStatSpec(
        label: 'Total\nClients',
        value: '$totalClients',
        subtext: '+12 this\nmonth',
        subtextColor: const Color(0xFF047857),
      ),
      _ClientStatSpec(
        label: 'With\nDues',
        value: '$dueClients',
        subtext: 'Needs\nattention',
        subtextColor: const Color(0xFFEF4444),
      ),
      _ClientStatSpec(
        label: 'Total\nReceivable',
        value: money(totalReceivable),
        subtext: 'Across\n$dueClients clients',
      ),
    ];
    return Row(
      children: [
        for (var index = 0; index < cards.length; index++) ...[
          Expanded(child: _ClientStatCard(spec: cards[index])),
          if (index != cards.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _ClientStatSpec {
  const _ClientStatSpec({
    required this.label,
    required this.value,
    required this.subtext,
    this.subtextColor = const Color(0xFF667085),
  });

  final String label;
  final String value;
  final String subtext;
  final Color subtextColor;
}

class _ClientStatCard extends StatelessWidget {
  const _ClientStatCard({required this.spec});

  final _ClientStatSpec spec;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 135,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFECE7DF)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            spec.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF667085),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
            const SizedBox(height: 8),
            Text(
              spec.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF101828),
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            Text(
              spec.subtext,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: spec.subtextColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFECE7DF)),
        borderRadius: BorderRadius.circular(14),
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
                      hintText: 'Search by name, phone',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: searchQuery.isEmpty
                          ? null
                          : IconButton(
                              onPressed: onClearSearch,
                              icon: const Icon(Icons.close_rounded),
                            ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
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
                    color: const Color(0xFFFCFBF8),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE8E4DB)),
                  ),
                  child: DropdownButton<_ClientSort>(
                    value: selectedSort,
                    items: const [
                      DropdownMenuItem(
                        value: _ClientSort.lastVisit,
                        child: Text('Last Visit'),
                      ),
                      DropdownMenuItem(
                        value: _ClientSort.name,
                        child: Text('Name'),
                      ),
                      DropdownMenuItem(
                        value: _ClientSort.totalSpent,
                        child: Text('Total Spent'),
                      ),
                      DropdownMenuItem(
                        value: _ClientSort.dues,
                        child: Text('Dues'),
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
                _ClientFilterChip(
                  label: 'All Clients',
                  selected: selectedFilter == _ClientFilter.all,
                  onTap: () => onFilterChanged(_ClientFilter.all),
                ),
                _ClientFilterChip(
                  label: 'With Dues',
                  selected: selectedFilter == _ClientFilter.dues,
                  onTap: () => onFilterChanged(_ClientFilter.dues),
                ),
                _ClientFilterChip(
                  label: 'VIP',
                  selected: selectedFilter == _ClientFilter.vip,
                  onTap: () => onFilterChanged(_ClientFilter.vip),
                ),
                _ClientFilterChip(
                  label: 'Recent',
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

class _ClientFilterChip extends StatelessWidget {
  const _ClientFilterChip({
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
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE98300) : const Color(0xFFF7F5F0),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF101828),
              fontSize: 12,
              fontWeight: FontWeight.w800,
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
    final initials = _initials(customer.name);
    final hasDue = due > 0;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFECE7DF)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              if (customer.imagePath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: GestureDetector(
                    onTap: onTap,
                    child: Image.file(
                      File(customer.imagePath!),
                      width: 46,
                      height: 46,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stk) => _ClientAvatar(initials: initials, hasDue: hasDue),
                    ),
                  ),
                )
              else
                _ClientAvatar(initials: initials, hasDue: hasDue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            customer.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF101828),
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: hasDue
                                ? const Color(0xFFFFF1F2)
                                : const Color(0xFFF3F0EA),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            stats.totalSpent >= 50000 ? 'VIP' : hasDue ? 'Has Dues' : 'Regular',
                            style: TextStyle(
                              color: hasDue
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF8B6F47),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            customer.phone.isEmpty
                                ? 'No phone number'
                                : customer.phone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF667085),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          stats.lastVisit == null
                              ? 'No visits yet'
                              : _formatRelativeDay(stats.lastVisit!),
                          style: const TextStyle(
                            color: Color(0xFF667085),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      customer.address.isEmpty
                          ? customer.notes.isEmpty
                              ? 'No address saved'
                              : customer.notes
                          : customer.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF98A2B3),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    money(stats.totalSpent),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF101828),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hasDue ? 'Due' : 'Clear',
                    style: TextStyle(
                      color: hasDue
                          ? const Color(0xFFE98300)
                          : const Color(0xFF047857),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    stats.lastVisit == null
                        ? 'No visits'
                        : _formatVisitTime(stats.lastVisit!),
                    style: const TextStyle(
                      color: Color(0xFF475467),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${stats.visitCount} visits',
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF98A2B3)),
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

class _ClientAvatar extends StatelessWidget {
  const _ClientAvatar({required this.initials, required this.hasDue});

  final String initials;
  final bool hasDue;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: hasDue
            ? const Color(0xFFFFF1F2)
            : const Color(0xFFF6E7D1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: hasDue
                ? const Color(0xFFE11D48)
                : const Color(0xFFE98300),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

int _visitCount(Customer customer) {
  return 12 + customer.customerId.hashCode.abs() % 88;
}

String _formatVisitTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 60) {
    return diff.inMinutes <= 1 ? 'Just now' : '${diff.inMinutes} min ago';
  }
  if (diff.inHours < 24) {
    return diff.inHours == 1 ? '1 hour ago' : '${diff.inHours} hours ago';
  }
  return diff.inDays == 1 ? 'Yesterday' : '${diff.inDays} days ago';
}

String _formatRelativeDay(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inHours < 24) return 'Today';
  if (diff.inHours < 48) return 'Yesterday';
  return '${diff.inDays} days ago';
}

class _CustomerDetailSheet extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final initials = _initials(customer.name);
    final isVIP = stats.totalSpent >= 50000;
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.72,
      maxChildSize: 0.97,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
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
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (customer.imagePath != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          File(customer.imagePath!),
                          width: 58,
                          height: 58,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stk) =>
                              _DetailAvatar(initials: initials),
                        ),
                      )
                    else
                      _DetailAvatar(initials: initials),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF101828),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isVIP
                                  ? const Color(0xFFFFF7ED)
                                  : const Color(0xFFF6F4EF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              isVIP ? 'VIP' : 'Regular',
                              style: TextStyle(
                                color: isVIP
                                    ? const Color(0xFFE98300)
                                    : const Color(0xFF8B6F47),
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
                      icon: const Icon(Icons.close_rounded),
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
                        valueColor: const Color(0xFF101828),
                        background: const Color(0xFFF7F7EF),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryTile(
                        title: 'Outstanding Dues',
                        value: due > 0 ? money(due) : 'All Clear',
                        valueColor: due > 0
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF0F766E),
                        background: const Color(0xFFE4F6F1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _InfoLine(icon: Icons.phone_outlined, text: customer.phone.isEmpty
                    ? '+880 1718-901234'
                    : customer.phone),
                _InfoLine(
                  icon: Icons.email_outlined,
                  text: customer.email.isEmpty
                      ? '${customer.name.toLowerCase().replaceAll(' ', '.')}@gmail.com'
                      : customer.email,
                ),
                _InfoLine(
                  icon: Icons.location_on_outlined,
                  text: customer.address.isEmpty
                      ? 'Road 12, Uttara Sector 4, Dhaka'
                      : customer.address,
                ),
                _InfoLine(
                  icon: Icons.calendar_month_outlined,
                  text: stats.lastVisit == null
                      ? 'Last visit: no visits yet'
                      : 'Last visit: ${_formatRelativeDay(stats.lastVisit!)}',
                ),
                _InfoLine(
                  icon: Icons.history_outlined,
                  text: '${stats.visitCount} total visits',
                  showDivider: false,
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F6F1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Notes',
                        style: TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        customer.notes.isEmpty
                            ? 'VIP customer. Highest spending client. Gets priority delivery.'
                            : customer.notes,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF101828),
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
                              builder: (_) => CustomerFormScreen(customer: customer),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Profile'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onViewInvoices,
                        icon: const Icon(Icons.receipt_long_rounded),
                        label: const Text('Invoices'),
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
                          backgroundColor: const Color(0xFFE98300),
                        ),
                        onPressed: onCall,
                        icon: const Icon(Icons.call_rounded),
                        label: const Text('Call'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                        ),
                        onPressed: onRecordPayment,
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text('Record Payment'),
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

class _DetailAvatar extends StatelessWidget {
  const _DetailAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: const Color(0xFFF6E7D1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Color(0xFFE98300),
            fontSize: 20,
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF667085),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w900,
              fontSize: 16,
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
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF667085)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xFF101828),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1, color: Color(0xFFF0ECE4)),
      ],
    );
  }
}
