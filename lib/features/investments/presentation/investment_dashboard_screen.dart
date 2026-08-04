import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';
import '../providers/investment_providers.dart';
import 'add_investment_sheet.dart';
import 'widgets/category_chip.dart';
import 'widgets/investment_card.dart';
import 'reports/investment_report_screen.dart';
import 'reports/outstanding_report_screen.dart';
import 'reports/payout_history_screen.dart';
import '../../investors/presentation/investor_list_screen.dart';
import '../../investors/presentation/investor_report_screen.dart';

class InvestmentDashboardScreen extends ConsumerStatefulWidget {
  const InvestmentDashboardScreen({super.key});

  @override
  ConsumerState<InvestmentDashboardScreen> createState() =>
      _InvestmentDashboardScreenState();
}

class _InvestmentDashboardScreenState
    extends ConsumerState<InvestmentDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();
    ref.read(investmentServiceProvider).seedDefaultCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dashboard = ref.watch(investmentDashboardProvider);
    final filtered = ref.watch(filteredInvestmentsProvider);
    final query = ref.watch(investmentSearchQueryProvider);
    final selectedCat = ref.watch(investmentCategoryFilterProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Investments',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: colors.onSurface,
          ),
        ),
        actions: [
          const NotificationBell(),
          const SizedBox(width: 4),
          const ShopAvatar(radius: 16, backgroundColor: Color(0xFFF97316), textColor: Colors.white),
          const SizedBox(width: 8),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: RefreshIndicator(
          onRefresh: () => Future.delayed(const Duration(milliseconds: 500)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _SummaryCards(data: dashboard),
              const SizedBox(height: 14),
              _OutstandingCard(data: dashboard),
              const SizedBox(height: 14),
              if (dashboard.categoryTotals.isNotEmpty)
                _CategoryBreakdownCard(data: dashboard),
              const SizedBox(height: 14),
              _FilterChips(selectedCat: selectedCat, onChanged: (cat) =>
                  ref.read(investmentCategoryFilterProvider.notifier).update(cat)),
              const SizedBox(height: 12),
              Text(
                'All Investments (${filtered.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              if (filtered.isEmpty && query.isEmpty)
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
                ...filtered.map(
                  (inv) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InvestmentCard(investment: inv),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const AddInvestmentSheet(),
          );
        },
        backgroundColor: const Color(0xFFF97316),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.data});
  final InvestmentDashboardData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF97316).withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total Invested',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(money(data.totalInvested),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                const Text('Capital deployed',
                    style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total Returns',
                    style: TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(money(data.totalReturns),
                    style: const TextStyle(
                        color: Color(0xFF101828),
                        fontSize: 28,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  data.roi >= 0
                      ? 'ROI ${data.roi.toStringAsFixed(2)}%'
                      : 'Loss ${data.roi.toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: data.roi >= 0
                        ? const Color(0xFF047857)
                        : const Color(0xFFDC2626),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OutstandingCard extends StatelessWidget {
  const _OutstandingCard({required this.data});
  final InvestmentDashboardData data;

  @override
  Widget build(BuildContext context) {
    final progress = data.totalInvested > 0
        ? (data.totalReturns / data.totalInvested).clamp(0.0, 1.0)
        : 0.0;
    final isPos = data.roi >= 0;
    final roiColor =
        isPos ? const Color(0xFF047857) : const Color(0xFFDC2626);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Outstanding Capital',
                        style: TextStyle(
                            color: Color(0xFF667085),
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(
                      money(data.totalOutstanding),
                      style: const TextStyle(
                          color: Color(0xFF101828),
                          fontSize: 28,
                          fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 56,
                      height: 56,
                      child: CircularProgressIndicator(
                        value: data.roi.abs().clamp(0, 100) / 100,
                        strokeWidth: 5,
                        backgroundColor: roiColor.withValues(alpha: 0.12),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(roiColor),
                      ),
                    ),
                    Text(
                      '${data.roi.abs().toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: roiColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFF97316).withValues(alpha: 0.12),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFFF97316)),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Return on investment progress',
            style: TextStyle(
                color: Color(0xFF98A2B3),
                fontSize: 11,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _CategoryBreakdownCard extends StatelessWidget {
  const _CategoryBreakdownCard({required this.data});
  final InvestmentDashboardData data;

  @override
  Widget build(BuildContext context) {
    final sorted = data.categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Investment by Category',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: Color(0xFF101828))),
          const SizedBox(height: 16),
          ...sorted.map((e) {
            final pct = data.totalInvested > 0
                ? (e.value / data.totalInvested)
                : 0.0;
            final c = _catColor(e.key);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(data.categoryNames[e.key] ?? e.key,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475467))),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct.clamp(0.0, 1.0),
                        backgroundColor: c.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation<Color>(c),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 70,
                    child: Text(money(e.value),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF101828))),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _catColor(String id) {
    switch (id) {
      case 'setup':
        return const Color(0xFFF97316);
      case 'equipment':
        return const Color(0xFF0F766E);
      case 'technology':
        return const Color(0xFF2563EB);
      case 'inventory':
        return const Color(0xFF7C3AED);
      case 'vehicle':
        return const Color(0xFFDC2626);
      case 'marketing':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF98A2B3);
    }
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips(
      {required this.selectedCat, required this.onChanged});
  final String selectedCat;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, _) {
      final cats = ref.watch(investmentCategoriesStreamProvider).value ?? [];
      return SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: cats.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            if (i == 0) {
              return CategoryChip(
                  label: 'All',
                  selected: selectedCat.isEmpty,
                  onTap: () => onChanged(''));
            }
            final cat = cats[i - 1];
            return CategoryChip(
                label: cat.name,
                selected: selectedCat == cat.id,
                onTap: () =>
                    onChanged(selectedCat == cat.id ? '' : cat.id));
          },
        ),
      );
    });
  }
}
