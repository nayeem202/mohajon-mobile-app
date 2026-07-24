import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/money.dart';
import '../../models/investment.dart';
import '../../models/investment_member.dart';
import '../../models/payout.dart';
import '../../providers/investment_providers.dart';
import 'payout_dialog.dart';
import 'profit_badge.dart';

class InvestmentCard extends ConsumerStatefulWidget {
  const InvestmentCard({super.key, required this.investment});

  final Investment investment;

  @override
  ConsumerState<InvestmentCard> createState() => _InvestmentCardState();
}

class _InvestmentCardState extends ConsumerState<InvestmentCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  bool _showHistory = false;

  @override
  Widget build(BuildContext context) {
    final inv = widget.investment;
    final members = ref.watch(investmentMembersProvider(inv.id));
    final payoutsAsync = ref.watch(payoutsStreamProvider(inv.id));
    final payouts = payoutsAsync.value ?? [];
    final colors = Theme.of(context).colorScheme;
    final catColor = _categoryColor(inv.categoryName, colors);
    final progress = inv.totalInvestment > 0
        ? (inv.totalPaid / inv.totalInvestment).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(_categoryIcon(inv.categoryName),
                            color: catColor, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(inv.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: colors.onSurface,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: catColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(inv.categoryName,
                                      style: TextStyle(
                                          color: catColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: inv.profitShareMethod == 'fixed'
                                        ? const Color(0xFFFEF3C7)
                                        : const Color(0xFFE0F2FE),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    inv.profitShareMethod == 'fixed'
                                        ? 'Fixed %'
                                        : 'Proportional',
                                    style: TextStyle(
                                      color: inv.profitShareMethod == 'fixed'
                                          ? const Color(0xFFD97706)
                                          : colors.tertiary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(money(inv.totalInvestment),
                              style: TextStyle(
                                  color: colors.onSurface,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16)),
                          const SizedBox(height: 4),
                          ProfitBadge(value: inv.roi, suffix: '%'),
                        ],
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _expanded = !_expanded),
                        child: AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: colors.outline),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor:
                          colors.primary.withValues(alpha: 0.12),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(colors.primary),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildExpanded(
                inv, members, payouts, colors, catColor),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildExpanded(Investment inv, List<InvestmentMember> members,
      List<Payout> payouts, ColorScheme colors, Color catColor) {
    final totalDue =
        members.fold<double>(0, (s, m) => s + m.investmentAmount + m.profit);
    final totalPaid = members.fold<double>(0, (s, m) => s + m.paidAmount);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: const Color(0xFFF0ECE4)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Row(
            children: [
              _StatBox(
                  label: 'Investors',
                  value: '${members.length}',
                  color: colors.primary),
              const SizedBox(width: 8),
              _StatBox(
                  label: 'Total Returns',
                  value: money(inv.totalProfit),
                  color: const Color(0xFF047857)),
              const SizedBox(width: 8),
              _StatBox(
                  label: 'Outstanding',
                  value: money(inv.outstanding),
                  color: inv.outstanding > 0
                      ? colors.error
                      : const Color(0xFF047857)),
            ],
          ),
          const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.payments_rounded,
                        color: colors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text('Total Paid Out',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: colors.primary,
                            fontSize: 13)),
                    const Spacer(),
                    Tooltip(
                      message: 'Outstanding Capital = Total Investment + Profit - Total Paid Out',
child: Text(money(totalPaid),
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: colors.primary,
                                fontSize: 15)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Tooltip(
                        message: 'Percentage of total due (investment + profit) that has been paid out',
                        child: Text(
                          '${totalDue > 0 ? (totalPaid / totalDue * 100).toStringAsFixed(0) : '0'}% Cleared',
style: TextStyle(
                                color: colors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 14),
          Row(
            children: [
Text('INVESTOR BREAKDOWN',
                    style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5)),
              const Spacer(),
              GestureDetector(
                onTap: () =>
                    setState(() => _showHistory = !_showHistory),
                child: Row(
                  children: [
                    Text(
                        _showHistory
                            ? 'Hide History'
                            : 'View Payout History',
                        style: TextStyle(
                            color: colors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    Icon(
                      _showHistory
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 16,
color: colors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...members.map((m) => _MemberCard(
              member: m,
              inv: inv,
              onPayout: () => _showPayout(inv.id, m))),
          if (_showHistory) ...[
            const SizedBox(height: 8),
            if (payouts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('No payouts recorded yet.',
                    style: TextStyle(
                        color: colors.outline, fontSize: 13)),
              )
            else
              ...payouts.take(5).map(
                  (p) => _PayoutHistoryItem(payout: p)),
          ],
        ],
      ),
    );
  }

  void _showPayout(String investmentId, InvestmentMember member) {
    showDialog(
      context: context,
      builder: (_) => PayoutDialog(
          investmentId: investmentId, member: member),
    );
  }

  Color _categoryColor(String cat, ColorScheme colors) {
    switch (cat) {
      case 'Setup':
        return colors.primary;
      case 'Equipment':
        return colors.secondary;
      case 'Technology':
        return colors.tertiary;
      case 'Inventory':
        return const Color(0xFF7C3AED);
      case 'Vehicle':
        return colors.error;
      case 'Marketing':
        return const Color(0xFFF59E0B);
      default:
        return colors.outline;
    }
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'Setup':
        return Icons.construction_rounded;
      case 'Equipment':
        return Icons.precision_manufacturing_rounded;
      case 'Technology':
        return Icons.computer_rounded;
      case 'Inventory':
        return Icons.inventory_2_rounded;
      case 'Vehicle':
        return Icons.local_shipping_rounded;
      case 'Marketing':
        return Icons.campaign_rounded;
      default:
        return Icons.account_balance_rounded;
    }
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox(
      {required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _MemberCard extends ConsumerWidget {
  const _MemberCard({
    required this.member,
    required this.inv,
    required this.onPayout,
  });

  final InvestmentMember member;
  final Investment inv;
  final VoidCallback onPayout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final investor =
        ref.watch(memberInvestorProvider(member.investorId));
    final netDue =
        member.investmentAmount + member.profit - member.paidAmount;
    final totalDue = member.investmentAmount + member.profit;
    final progress = totalDue > 0
        ? (member.paidAmount / totalDue).clamp(0.0, 1.0)
        : 0.0;
    final colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0ECE4)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor:
                    colors.primary.withValues(alpha: 0.12),
                child: Text(
                  investor != null && investor.name.isNotEmpty
                      ? investor.name[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(investor?.name ?? 'Unknown',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                        fontSize: 14)),
              ),
              InkWell(
                onTap: onPayout,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Record Payout',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _MiniStat(
                  label: 'Invested',
                  value: money(member.investmentAmount),
                  color: colors.primary),
              const SizedBox(width: 6),
              _MiniStat(
                  label: 'Share',
                  value:
                      '${member.sharePercentage.toStringAsFixed(1)}%',
                  color: colors.onSurfaceVariant),
              const SizedBox(width: 6),
              _MiniStat(
                  label: 'Profit',
                  value: money(member.profit),
                  color: const Color(0xFF047857)),
              const SizedBox(width: 6),
              _MiniStat(
                label: 'Net Due',
                value: money(netDue),
                color: netDue > 0
                    ? colors.error
                    : const Color(0xFF047857),
                tooltip: 'Net Due = Investment Amount + Profit - Paid Amount. Payouts reduce this balance.',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: colors.primary.withValues(alpha: 0.12),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(colors.primary),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('Total Due ${money(totalDue)}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurfaceVariant)),
              const SizedBox(width: 4),
              Text('Paid ${money(member.paidAmount)}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.primary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
    this.tooltip,
  });

  final String label;
  final String value;
  final Color color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: tooltip != null
          ? Tooltip(
              message: tooltip!,
              child: _miniStatContent(),
            )
          : _miniStatContent(),
    );
  }

  Widget _miniStatContent() {
    return Column(
      children: [
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: color.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _PayoutHistoryItem extends StatelessWidget {
  const _PayoutHistoryItem({required this.payout});
  final Payout payout;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 18, color: Color(0xFF047857)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              payout.note.isNotEmpty ? payout.note : 'Payout',
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475467),
                  fontSize: 13),
            ),
          ),
          Text(money(payout.amount),
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: colors.onSurface,
                  fontSize: 13)),
          const SizedBox(width: 8),
          Text(
            '${payout.createdAt.day}/${payout.createdAt.month}',
            style: TextStyle(
                color: colors.outline,
                fontSize: 11,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
