import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/premium_header.dart';
import '../providers/investment_providers.dart';
import 'add_investment_sheet.dart';
import 'widgets/category_chip.dart';
import 'widgets/investment_card.dart';

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
    final l10n = AppLocalizations.of(context);
    final dashboard = ref.watch(investmentDashboardProvider);
    final filtered = ref.watch(filteredInvestmentsProvider);
    final query = ref.watch(investmentSearchQueryProvider);
    final selectedCat = ref.watch(investmentCategoryFilterProvider);

    return Theme(
      data: MohajonWarm.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: MohajonWarm.pageGradient,
          ),
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: RefreshIndicator(
                onRefresh: () => Future.delayed(const Duration(milliseconds: 500)),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                  children: [
                    PremiumHeader(
                      title: l10n.t('investmentsHeader'),
                      subtitle: l10n.t('capitalReturns'),
                      icon: Icons.account_balance_rounded,
                    ),
                    const SizedBox(height: 18),
                    _SummaryCards(data: dashboard),
                    const SizedBox(height: 14),
                    _OutstandingCard(data: dashboard),
                    const SizedBox(height: 14),
                    if (dashboard.categoryTotals.isNotEmpty)
                      _CategoryBreakdownCard(data: dashboard),
                    const SizedBox(height: 14),
                    _FilterChips(
                      selectedCat: selectedCat,
                      onChanged: (cat) => ref
                          .read(investmentCategoryFilterProvider.notifier)
                          .update(cat),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.tP('allInvestments', {'n': '${filtered.length}'}),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: MohajonWarm.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (filtered.isEmpty && query.isEmpty)
                      EmptyState(
                        message: l10n.t('addInvestmentsToTrack'),
                        icon: Icons.account_balance_outlined,
                      )
                    else if (filtered.isEmpty)
                      EmptyState(
                        message: l10n.t('noInvestmentsMatch'),
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
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.data});
  final InvestmentDashboardData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isPos = data.roi >= 0;
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 130,
            padding: const EdgeInsets.all(14),
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
                  color: MohajonWarm.goldText.withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
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
                            color: MohajonWarm.goldText.withValues(alpha: 0.18),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(Icons.account_balance_wallet_rounded,
                          color: MohajonWarm.goldText, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: MohajonWarm.goldText.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          l10n.t('totalInvested'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: MohajonWarm.goldText,
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
                    money(data.totalInvested),
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 22,
                      color: MohajonWarm.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.t('capitalDeployed'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: MohajonWarm.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 130,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [MohajonWarm.tintOrange, MohajonWarm.card],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: MohajonWarm.goldBorder),
              boxShadow: [
                BoxShadow(
                  color: MohajonWarm.orange.withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
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
                            color: MohajonWarm.orange.withValues(alpha: 0.18),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(Icons.trending_up_rounded,
                          color: MohajonWarm.orange, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: MohajonWarm.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          l10n.t('totalReturns'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: MohajonWarm.orange,
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
                    money(data.totalReturns),
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 22,
                      color: MohajonWarm.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.roi >= 0
                      ? l10n.tP('roiPct',
                          {'pct': data.roi.toStringAsFixed(2)})
                      : l10n.tP('lossPct',
                          {'pct': data.roi.toStringAsFixed(2)}),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isPos ? MohajonWarm.green : MohajonWarm.red,
                    fontSize: 11,
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
    final l10n = AppLocalizations.of(context);
    final progress = data.totalInvested > 0
        ? (data.totalReturns / data.totalInvested).clamp(0.0, 1.0)
        : 0.0;
    final isPos = data.roi >= 0;
    final roiColor = isPos ? MohajonWarm.green : MohajonWarm.red;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [MohajonWarm.card, MohajonWarm.tintGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MohajonWarm.goldBorder),
        boxShadow: [
          BoxShadow(
            color: MohajonWarm.ink.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_rounded,
                  color: MohajonWarm.green, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.t('outstandingCapital'),
                        style: const TextStyle(
                            color: MohajonWarm.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(
                      money(data.totalOutstanding),
                      style: const TextStyle(
                          color: MohajonWarm.ink,
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
                        valueColor: AlwaysStoppedAnimation<Color>(roiColor),
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
              backgroundColor: MohajonWarm.primary.withValues(alpha: 0.12),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(MohajonWarm.primary),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.t('roiProgress'),
            style: const TextStyle(
                color: MohajonWarm.muted,
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
    final l10n = AppLocalizations.of(context);
    final sorted = data.categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MohajonWarm.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MohajonWarm.goldBorder),
        boxShadow: [
          BoxShadow(
            color: MohajonWarm.ink.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.t('investmentByCategory'),
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: MohajonWarm.ink)),
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
                            color: MohajonWarm.ink)),
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
                            color: MohajonWarm.ink)),
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
        return MohajonWarm.primary;
      case 'equipment':
        return const Color(0xFF0F766E);
      case 'technology':
        return MohajonWarm.green;
      case 'inventory':
        return MohajonWarm.orange;
      case 'vehicle':
        return MohajonWarm.red;
      case 'marketing':
        return const Color(0xFFB45309);
      default:
        return MohajonWarm.muted;
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
      final l10n = AppLocalizations.of(context);
      final cats = ref.watch(investmentCategoriesStreamProvider).value ?? [];
      return SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: cats.length + 1,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            if (i == 0) {
              return CategoryChip(
                  label: l10n.t('all'),
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
