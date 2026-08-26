import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';
import '../models/investor.dart';
import '../providers/investor_providers.dart';
import 'investor_form_screen.dart';
import 'widgets/investor_card.dart';

class InvestorListScreen extends ConsumerStatefulWidget {
  const InvestorListScreen({super.key});

  @override
  ConsumerState<InvestorListScreen> createState() =>
      _InvestorListScreenState();
}

class _InvestorListScreenState extends ConsumerState<InvestorListScreen> {
  final _searchController = TextEditingController();
  bool _pnlExpanded = false;
  bool _showSearch = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = ref.watch(filteredInvestorsProvider);
    final query = ref.watch(investorSearchQueryProvider);
    final overview = ref.watch(investorsOverviewProvider);
    final businessProfit = ref.watch(businessProfitProvider);

    return Theme(
      data: MohajonWarm.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: MohajonWarm.surface,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: MohajonWarm.pageGradient,
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              child: Column(
                children: [
                  _Header(
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: MohajonWarm.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: MohajonWarm.goldBorder),
                      boxShadow: [
                        BoxShadow(
                          color: MohajonWarm.primary.withValues(
                            alpha: 0.14,
                          ),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '${overview.totalInvestors}',
                                maxLines: 1,
                                style: const TextStyle(
                                  color: MohajonWarm.ink,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const Spacer(),
                            _HeroPill(label: 'Net P&L'),
                            const SizedBox(width: 8),
                            _HeroPill(label: 'Outstanding'),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Total Investors',
                          style: TextStyle(
                            color: MohajonWarm.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryBox(
                          label: 'Total Invested',
                          value: money(overview.totalInvestment),
                          color: MohajonWarm.goldText,
                          background: MohajonWarm.tintYellow,
                          icon: Icons.paid_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SummaryBox(
                          label: 'Outstanding',
                          value: money(overview.totalOutstanding),
                          color: MohajonWarm.orange,
                          background: MohajonWarm.tintOrange,
                          icon: Icons.hourglass_top_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _Panel(
                    icon: Icons.assessment_rounded,
                    iconColor: MohajonWarm.green,
                    iconBackground: MohajonWarm.tintGreen,
                    title: 'Business Profit & Loss',
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _ProfitMetric(
                              label: 'Gross Profit',
                              value: money(businessProfit.grossProfit),
                              color: MohajonWarm.green,
                              background: MohajonWarm.tintGreen,
                              icon: Icons.trending_up_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ProfitMetric(
                              label: 'Gross Loss',
                              value: money(businessProfit.grossLoss),
                              color: MohajonWarm.red,
                              background: MohajonWarm.tintRed,
                              icon: Icons.trending_down_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _ProfitMetric(
                              label: 'Expenses',
                              value: money(businessProfit.totalExpense),
                              color: MohajonWarm.orange,
                              background: MohajonWarm.tintOrange,
                              icon: Icons.receipt_long_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ProfitMetric(
                              label: 'Net Profit / Loss',
                              value: money(businessProfit.netProfit),
                              color: businessProfit.netProfit >= 0
                                  ? MohajonWarm.green
                                  : MohajonWarm.red,
                              background: businessProfit.netProfit >= 0
                                  ? MohajonWarm.tintGreen
                                  : MohajonWarm.tintRed,
                              icon: businessProfit.netProfit >= 0
                                  ? Icons.savings_rounded
                                  : Icons.trending_down_rounded,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: MohajonWarm.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: MohajonWarm.goldBorder),
                      boxShadow: [
                        BoxShadow(
                          color: MohajonWarm.ink.withValues(alpha: 0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () =>
                              setState(() => _pnlExpanded = !_pnlExpanded),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: MohajonWarm.tintYellow,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: const Icon(
                                  Icons.pie_chart_rounded,
                                  color: MohajonWarm.goldText,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Profit / Loss Sharing Methods',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    letterSpacing: -0.2,
                                    color: MohajonWarm.ink,
                                  ),
                                ),
                              ),
                              AnimatedRotation(
                                turns:
                                    _pnlExpanded ? 0.5 : 0,
                                duration:
                                    const Duration(milliseconds: 200),
                                child: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: MohajonWarm.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ClipRect(
                          child: AnimatedAlign(
                            duration:
                                const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            alignment: Alignment.topCenter,
                            heightFactor: _pnlExpanded ? 1 : 0,
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 14),
                                IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: Container(
                                          padding:
                                              const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: MohajonWarm
                                                .tintYellow,
                                            borderRadius:
                                                BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: MohajonWarm
                                                  .primary
                                                  .withValues(
                                                alpha: 0.35,
                                              ),
                                            ),
                                          ),
                                          child:
                                              const Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Proportional',
                                                style: TextStyle(
                                                  fontWeight:
                                                      FontWeight.w900,
                                                  color:
                                                      Color(0xFF5D4A00),
                                                  fontSize: 13,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                'Profit automatically calculated according to contribution.',
                                                style: TextStyle(
                                                  color: Color(0xFF8A6500),
                                                  fontSize: 11,
                                                  fontWeight:
                                                      FontWeight.w600,
                                                  height: 1.4,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Container(
                                          padding:
                                              const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: MohajonWarm
                                                  .goldBorder,
                                            ),
                                          ),
                                          child:
                                              const Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Fixed Rate',
                                                style: TextStyle(
                                                  fontWeight:
                                                      FontWeight.w900,
                                                  color: MohajonWarm.ink,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                'Manual percentage regardless of contribution.',
                                                style: TextStyle(
                                                  color: MohajonWarm.muted,
                                                  fontSize: 11,
                                                  fontWeight:
                                                      FontWeight.w600,
                                                  height: 1.4,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'How Paid Out Is Calculated',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                    color: MohajonWarm.ink,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _StepRow(
                                  number: '1',
                                  label: 'Total Due',
                                  desc: 'Investment + Profit',
                                ),
                                _StepRow(
                                  number: '2',
                                  label: 'Paid Out',
                                  desc: 'Sum of payouts',
                                ),
                                _StepRow(
                                  number: '3',
                                  label: 'Outstanding',
                                  desc: 'Total Due – Paid',
                                  showDivider: false,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_showSearch) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _searchController,
                      onChanged: (v) => ref
                          .read(investorSearchQueryProvider.notifier)
                          .update(v),
                      decoration: InputDecoration(
                        hintText: 'Search by name or phone...',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: MohajonWarm.muted,
                        ),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  ref
                                      .read(
                                        investorSearchQueryProvider
                                            .notifier,
                                      )
                                      .update('');
                                },
                                icon: const Icon(
                                  Icons.clear_rounded,
                                  color: MohajonWarm.muted,
                                ),
                              ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (filtered.isEmpty)
                    const EmptyState(
                      message: 'No investors found. Add one to get started.',
                      icon: Icons.people_outline_rounded,
                    )
                  else
                    ...filtered.map(
                      (inv) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InvestorCard(
                          investor: inv,
                          onEdit: () => _openEdit(inv),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.small(
              heroTag: 'investorSearch',
              onPressed: () {
                setState(() => _showSearch = !_showSearch);
                if (!_showSearch) {
                  _searchController.clear();
                  ref.read(investorSearchQueryProvider.notifier).update('');
                }
              },
              child: Icon(
                _showSearch ? Icons.close : Icons.search_rounded,
                size: 22,
              ),
            ),
            const SizedBox(height: 8),
            FloatingActionButton(
              heroTag: 'investorAdd',
              onPressed: () => _showAddDialog(context),
              child: const Icon(Icons.person_add_rounded, size: 26),
            ),
          ],
        ),
      ),
    );
  }

  void _openEdit(Investor investor) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => InvestorFormScreen(investor: investor)),
    );
  }

  void _showAddDialog(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const InvestorFormScreen()),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            borderRadius: BorderRadius.circular(11),
            onTap: onBack,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: MohajonWarm.goldBorder),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: MohajonWarm.ink,
                size: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
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
            Icons.people_alt_rounded,
            color: MohajonWarm.ink,
            size: 17,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Investors',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: MohajonWarm.ink,
                ),
              ),
              Text(
                'Capital & payouts',
                style: TextStyle(
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
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: MohajonWarm.tintYellow,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: MohajonWarm.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: MohajonWarm.goldText,
          fontWeight: FontWeight.w900,
          fontSize: 11.5,
        ),
      ),
    );
  }
}

class _SummaryBox extends StatelessWidget {
  const _SummaryBox({
    required this.label,
    required this.value,
    required this.color,
    required this.background,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final Color background;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [background, MohajonWarm.card],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MohajonWarm.goldBorder),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.16),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
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
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MohajonWarm.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MohajonWarm.goldBorder),
        boxShadow: [
          BoxShadow(
            color: MohajonWarm.ink.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
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
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MohajonWarm.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _ProfitMetric extends StatelessWidget {
  const _ProfitMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.background,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final Color background;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [background, MohajonWarm.card],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MohajonWarm.goldBorder),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.14),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.18),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 15.5,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: MohajonWarm.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.label,
    required this.desc,
    this.showDivider = true,
  });

  final String number;
  final String label;
  final String desc;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      MohajonWarm.primary,
                      MohajonWarm.primaryPale,
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    number,
                    style: const TextStyle(
                      color: MohajonWarm.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: MohajonWarm.ink,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                desc,
                style: const TextStyle(
                  color: MohajonWarm.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, color: Color(0xFFF3ECDA)),
      ],
    );
  }
}
