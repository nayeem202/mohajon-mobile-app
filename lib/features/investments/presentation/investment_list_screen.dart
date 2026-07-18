import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../models/investment_item.dart';
import '../providers/investment_item_providers.dart';
import 'investment_detail_screen.dart';
import 'investment_form_sheet.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';

class InvestmentListScreen extends ConsumerStatefulWidget {
  const InvestmentListScreen({super.key});

  @override
  ConsumerState<InvestmentListScreen> createState() => _InvestmentListScreenState();
}

class _InvestmentListScreenState extends ConsumerState<InvestmentListScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _searchController;
  InvestmentSort _sort = InvestmentSort.newest;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final investmentsAsync = ref.watch(investmentsProvider);
    final searchQuery = ref.watch(investmentSearchQueryProvider);
    final selectedCategory = ref.watch(investmentCategoryFilterProvider);
    final overview = ref.watch(investmentItemsOverviewProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F1),
      body: SafeArea(
        child: investmentsAsync.when(
          data: (items) {
            final filtered = ref.watch(filteredInvestmentsProvider);

            return FadeTransition(
              opacity: _fadeAnim,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _InvestmentsTopBar(onAddInvestment: _openAddInvestment),
                  const SizedBox(height: 18),
                  _InvestmentDashboard(
                    overview: overview,
                    onAddInvestment: _openAddInvestment,
                  ),
                  const SizedBox(height: 18),
                  _SearchAndFilters(
                    controller: _searchController,
                    searchQuery: searchQuery,
                    selectedSort: _sort,
                    selectedCategory: selectedCategory,
                    onSearchChanged: (value) =>
                        ref.read(investmentSearchQueryProvider.notifier).state = value,
                    onClearSearch: () {
                      _searchController.clear();
                      ref.read(investmentSearchQueryProvider.notifier).state = '';
                    },
                    onSortChanged: (sort) {
                      setState(() => _sort = sort);
                      ref.read(investmentSortProvider.notifier).state = sort;
                    },
                    onCategoryChanged: (cat) =>
                        ref.read(investmentCategoryFilterProvider.notifier).state = cat,
                  ),
                  const SizedBox(height: 14),
                  if (items.isEmpty)
                    const EmptyState(
                      message: 'Add investments to track your capital.',
                      icon: Icons.account_balance_outlined,
                    )
                  else if (filtered.isEmpty)
                    const EmptyState(
                      message: 'No investments match your search.',
                      icon: Icons.search_off_rounded,
                    )
                  else
                    _InvestmentList(
                      investments: filtered,
                      onInvestmentTap: (inv) => _openInvestmentDetail(inv),
                    ),
                ],
              ),
            );
          },
          error: (error, _) => EmptyState(message: error.toString()),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddInvestment,
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  void _openAddInvestment() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const InvestmentFormSheet(),
    );
  }

  void _openInvestmentDetail(InvestmentItem investment) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InvestmentDetailScreen(investment: investment),
      ),
    );
  }
}

class _InvestmentsTopBar extends StatelessWidget {
  const _InvestmentsTopBar({required this.onAddInvestment});
  final VoidCallback onAddInvestment;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFF0F766E),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.account_balance_rounded,
            color: Colors.white,
            size: 17,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Investments',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF101828),
            ),
          ),
        ),
        const NotificationBell(),
        const SizedBox(width: 14),
        const ShopAvatar(radius: 17, backgroundColor: Color(0xFFE0F2FE), textColor: Color(0xFF2563EB)),
      ],
    );
  }
}

class _InvestmentDashboard extends StatelessWidget {
  const _InvestmentDashboard({
    required this.overview,
    required this.onAddInvestment,
  });

  final InvestmentOverview overview;
  final VoidCallback onAddInvestment;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _DashCard(
                label: 'Total Invested',
                value: money(overview.totalInvested),
                icon: Icons.trending_up_rounded,
                color: colors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DashCard(
                label: 'Total Returns',
                value: money(overview.totalReturned),
                icon: Icons.payments_rounded,
                color: colors.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _DashCard(
                label: 'Outstanding',
                value: money(overview.totalOutstanding),
                icon: Icons.account_balance_wallet_rounded,
                color: colors.tertiary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ROICard(roi: overview.totalRoi),
            ),
          ],
        ),
        if (overview.categoryTotals.isNotEmpty) ...[
          const SizedBox(height: 16),
          _CategoryBreakdown(
            categoryTotals: overview.categoryTotals,
            totalInvested: overview.totalInvested,
          ),
        ],
      ],
    );
  }
}

class _DashCard extends StatelessWidget {
  const _DashCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFECE7DF)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF101828),
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
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

class _ROICard extends StatelessWidget {
  const _ROICard({required this.roi});
  final double roi;

  @override
  Widget build(BuildContext context) {
    final isPositive = roi >= 0;
    final color = isPositive ? const Color(0xFF047857) : const Color(0xFFDC2626);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFECE7DF)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                    value: roi.abs().clamp(0, 100) / 100,
                    strokeWidth: 4,
                    backgroundColor: color.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                Icon(
                  isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  color: color,
                  size: 18,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ROI',
                  style: TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${roi.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
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

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({
    required this.categoryTotals,
    required this.totalInvested,
  });

  final Map<String, double> categoryTotals;
  final double totalInvested;

  @override
  Widget build(BuildContext context) {
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFECE7DF)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Category Breakdown',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: Color(0xFF101828),
            ),
          ),
          const SizedBox(height: 12),
          ...sortedCategories.map((entry) {
            final percentage = totalInvested > 0
                ? (entry.value / totalInvested * 100)
                : 0.0;
            final color = _categoryColor(entry.key);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475467),
                      ),
                    ),
                  ),
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF667085),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: color.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 70,
                    child: Text(
                      money(entry.value),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF101828),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Setup': return const Color(0xFFF97316);
      case 'Equipment': return const Color(0xFF0F766E);
      case 'Technology': return const Color(0xFF2563EB);
      case 'Inventory': return const Color(0xFF7C3AED);
      case 'Vehicle': return const Color(0xFFDC2626);
      case 'Marketing': return const Color(0xFFF59E0B);
      default: return const Color(0xFF98A2B3);
    }
  }
}

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.controller,
    required this.searchQuery,
    required this.selectedSort,
    required this.selectedCategory,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onSortChanged,
    required this.onCategoryChanged,
  });

  final TextEditingController controller;
  final String searchQuery;
  final InvestmentSort selectedSort;
  final String selectedCategory;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<InvestmentSort> onSortChanged;
  final ValueChanged<String> onCategoryChanged;

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
                      hintText: 'Search by investor, category...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: searchQuery.isEmpty
                          ? null
                          : IconButton(
                              onPressed: onClearSearch,
                              icon: const Icon(Icons.close_rounded),
                            ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
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
                  child: DropdownButton<InvestmentSort>(
                    value: selectedSort,
                    items: const [
                      DropdownMenuItem(value: InvestmentSort.newest, child: Text('Newest')),
                      DropdownMenuItem(value: InvestmentSort.oldest, child: Text('Oldest')),
                      DropdownMenuItem(value: InvestmentSort.highestAmount, child: Text('Highest Amount')),
                      DropdownMenuItem(value: InvestmentSort.lowestAmount, child: Text('Lowest Amount')),
                      DropdownMenuItem(value: InvestmentSort.highestRoi, child: Text('Highest ROI')),
                      DropdownMenuItem(value: InvestmentSort.alphabetical, child: Text('A-Z')),
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
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: investmentCategories.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _CategoryChip(
                    label: 'All',
                    selected: selectedCategory.isEmpty,
                    onTap: () => onCategoryChanged(''),
                  );
                }
                final cat = investmentCategories[index - 1];
                return _CategoryChip(
                  label: cat,
                  selected: selectedCategory == cat,
                  onTap: () => onCategoryChanged(selectedCategory == cat ? '' : cat),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0F766E) : const Color(0xFFF7F5F0),
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
    );
  }
}

class _InvestmentList extends StatelessWidget {
  const _InvestmentList({
    required this.investments,
    required this.onInvestmentTap,
  });

  final List<InvestmentItem> investments;
  final ValueChanged<InvestmentItem> onInvestmentTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < investments.length; index++) ...[
          if (index != 0) const SizedBox(height: 10),
          _InvestmentCard(
            investment: investments[index],
            onTap: () => onInvestmentTap(investments[index]),
          ),
        ],
      ],
    );
  }
}

class _InvestmentCard extends StatefulWidget {
  const _InvestmentCard({
    required this.investment,
    required this.onTap,
  });

  final InvestmentItem investment;
  final VoidCallback onTap;

  @override
  State<_InvestmentCard> createState() => _InvestmentCardState();
}

class _InvestmentCardState extends State<_InvestmentCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final inv = widget.investment;
    final isPositive = inv.roi >= 0;
    final roiColor = isPositive ? const Color(0xFF047857) : const Color(0xFFDC2626);
    final outstanding = inv.amount - inv.returnAmount;
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: widget.onTap,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFECE7DF)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: _categoryColor(inv.category).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _categoryIcon(inv.category),
                      color: _categoryColor(inv.category),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inv.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF101828),
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${inv.category}${inv.investorName.isNotEmpty ? ' · ${inv.investorName}' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF667085),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
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
                        money(inv.amount),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF101828),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'ROI ${inv.roi.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: roiColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      if (outstanding > 0)
                        Text(
                          'Due ${money(outstanding)}',
                          style: TextStyle(
                            color: colors.error,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF98A2B3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _InvestmentExpanded(investment: inv),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Setup': return const Color(0xFFF97316);
      case 'Equipment': return const Color(0xFF0F766E);
      case 'Technology': return const Color(0xFF2563EB);
      case 'Inventory': return const Color(0xFF7C3AED);
      case 'Vehicle': return const Color(0xFFDC2626);
      case 'Marketing': return const Color(0xFFF59E0B);
      default: return const Color(0xFF98A2B3);
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Setup': return Icons.construction_rounded;
      case 'Equipment': return Icons.precision_manufacturing_rounded;
      case 'Technology': return Icons.computer_rounded;
      case 'Inventory': return Icons.inventory_2_rounded;
      case 'Vehicle': return Icons.local_shipping_rounded;
      case 'Marketing': return Icons.campaign_rounded;
      default: return Icons.account_balance_rounded;
    }
  }
}

class _InvestmentExpanded extends StatelessWidget {
  const _InvestmentExpanded({required this.investment});
  final InvestmentItem investment;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final outstanding = investment.amount - investment.returnAmount;
    final isPositive = investment.roi >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: const Color(0xFFECE7DF)),
          right: BorderSide(color: const Color(0xFFECE7DF)),
          bottom: BorderSide(color: const Color(0xFFECE7DF)),
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, color: Color(0xFFF0ECE4)),
          const SizedBox(height: 12),
          _ExpRow(label: 'Investor', value: investment.investorName.isEmpty ? 'N/A' : investment.investorName),
          _ExpRow(label: 'Date', value: '${investment.date.day}/${investment.date.month}/${investment.date.year}'),
          _ExpRow(label: 'Returns', value: money(investment.returnAmount)),
          _ExpRow(label: 'Outstanding', value: outstanding > 0 ? money(outstanding) : 'Cleared',
              valueColor: outstanding > 0 ? colors.error : const Color(0xFF047857)),
          if (investment.description.isNotEmpty)
            _ExpRow(label: 'Description', value: investment.description),
          if (investment.notes.isNotEmpty)
            _ExpRow(label: 'Notes', value: investment.notes, showDivider: false),
        ],
      ),
    );
  }
}

class _ExpRow extends StatelessWidget {
  const _ExpRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 90,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? const Color(0xFF101828),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
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
