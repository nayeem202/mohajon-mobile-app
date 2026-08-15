import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/money.dart';
import '../../models/investor.dart';
import '../../providers/investor_providers.dart';
import '../../../investments/providers/investment_providers.dart';
import '../../../investments/models/investment_member.dart';

class InvestorCard extends ConsumerStatefulWidget {
  const InvestorCard({
    super.key,
    required this.investor,
    this.onTap,
  });

  final Investor investor;
  final VoidCallback? onTap;

  @override
  ConsumerState<InvestorCard> createState() => _InvestorCardState();
}

class _InvestorCardState extends ConsumerState<InvestorCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final inv = widget.investor;
    final financials = ref.watch(investorFinancialsProvider(inv.id));
    final colors = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
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
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: colors.primary.withValues(alpha: 0.12),
                    backgroundImage: inv.photoUrl.isNotEmpty
                        ? NetworkImage(inv.photoUrl)
                        : null,
                    child: inv.photoUrl.isEmpty
                        ? Text(
                            inv.name.isNotEmpty
                                ? inv.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                                color: colors.primary,
                                fontWeight: FontWeight.w900,
                                fontSize: 20))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(inv.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0xFF101828),
                                fontWeight: FontWeight.w900,
                                fontSize: 15)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (inv.phone.isNotEmpty) ...[
                              const Icon(Icons.phone_rounded,
                                  size: 12, color: Color(0xFF98A2B3)),
                              const SizedBox(width: 4),
                              Text(inv.phone,
                                  style: const TextStyle(
                                      color: Color(0xFF667085),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(width: 8),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Profit ${money(financials.profit)}',
                                style: const TextStyle(
                                    color: Color(0xFF047857),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  child: Text('${financials.investmentCount}',
                        style: TextStyle(
                            color: colors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 13)),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF98A2B3)),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildExpanded(inv, financials, colors),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildExpanded(
    Investor inv,
    InvestorFinancials financials,
    ColorScheme colors,
  ) {
    final totalDue = financials.investment + financials.profit;
    final progress = totalDue > 0
        ? ((totalDue - financials.outstanding) / totalDue)
            .clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: const Color(0xFFF0ECE4)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          if (inv.email.isNotEmpty || inv.phone.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F5F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  if (inv.phone.isNotEmpty) ...[
                    const Icon(Icons.phone_rounded,
                        size: 14, color: Color(0xFF667085)),
                    const SizedBox(width: 4),
                    Text(inv.phone,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF475467))),
                    if (inv.email.isNotEmpty) const SizedBox(width: 16),
                  ],
                  if (inv.email.isNotEmpty) ...[
                    const Icon(Icons.email_rounded,
                        size: 14, color: Color(0xFF667085)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(inv.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF475467))),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              _EStat(
                  label: 'Invested',
                  value: money(financials.investment),
                  color: colors.primary),
              const SizedBox(width: 6),
              _EStat(
                  label: 'Profit',
                  value: money(financials.profit),
                  color: const Color(0xFF047857)),
              const SizedBox(width: 6),
              _EStat(
                  label: 'Loss',
                  value: money(financials.loss),
                  color: colors.error),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _EStat(
                  label: 'Paid Out',
                  value: money(totalDue - financials.outstanding),
                  color: const Color(0xFF0F766E)),
              const SizedBox(width: 6),
              _EStat(
                  label: 'Outstanding',
                  value: money(financials.outstanding),
                  color: financials.outstanding > 0
                      ? colors.error
                      : const Color(0xFF047857)),
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
                    backgroundColor:
                        colors.primary.withValues(alpha: 0.12),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(colors.primary),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                  'Payout Progress ${(progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          if (financials.investmentCount > 0) ...[
            const SizedBox(height: 14),
            const Text('INVESTMENT DETAILS',
                style: TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5)),
            const SizedBox(height: 8),
            _InvestmentsList(investorId: inv.id),
          ],
        ],
      ),
    );
  }
}

class _EStat extends StatelessWidget {
  const _EStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
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
        ),
      ),
    );
  }
}

class _InvestmentsList extends ConsumerWidget {
  const _InvestmentsList({required this.investorId});
  final String investorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final investments =
        ref.watch(investmentsStreamProvider).value ?? [];
    final investorInvestments = investments.where((inv) {
      final members =
          ref.watch(investmentMembersProvider(inv.id));
      return members.any((m) => m.investorId == investorId);
    }).toList();

    if (investorInvestments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('No active investments.',
            style: TextStyle(
                color: Color(0xFF98A2B3), fontSize: 13)),
      );
    }

    return Column(
      children: investorInvestments.map((inv) {
        final members =
            ref.watch(investmentMembersProvider(inv.id));
        final member = members.where(
            (m) => m.investorId == investorId).firstOrNull;
        if (member == null) return const SizedBox.shrink();
        return _InvestmentMiniCard(
            investment: inv, member: member);
      }).toList(),
    );
  }
}

class _InvestmentMiniCard extends StatelessWidget {
  const _InvestmentMiniCard({
    required this.investment,
    required this.member,
  });

  final dynamic investment;
  final InvestmentMember member;

  @override
  Widget build(BuildContext context) {
    final inv = investment as dynamic;
    final netDue =
        member.investmentAmount + member.profit - member.paidAmount;
    final colors = Theme.of(context).colorScheme;

    final catColor = _catColor(inv.categoryName as String? ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F5F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0ECE4)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: catColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(inv.title as String? ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF101828),
                            fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(
                      '${inv.categoryName as String? ?? ''} · ${inv.createdAt != null ? '${(inv.createdAt as dynamic).day}/${(inv.createdAt as dynamic).month}/${(inv.createdAt as dynamic).year}' : ''}',
                      style: const TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 11,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _Mini(label: 'Contribution', value: money(member.investmentAmount)),
              _Mini(
                  label: 'Share',
                  value:
                      '${member.sharePercentage.toStringAsFixed(1)}%'),
              _Mini(
                  label: 'Profit',
                  value: money(member.profit),
                  color: const Color(0xFF047857)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _Mini(
                  label: 'Net Due',
                  value: money(netDue),
                  color: netDue > 0 ? colors.error : const Color(0xFF047857)),
              _Mini(
                  label: 'Paid',
                  value: money(member.paidAmount),
                  color: colors.primary),
              _Mini(
                  label: 'Remaining',
                  value: money(member.remainingAmount),
                  color: member.remainingAmount > 0
                      ? colors.error
                      : const Color(0xFF047857)),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 14, color: Color(0xFFF97316)),
                const SizedBox(width: 6),
                Text(
                  'Share calculated by contribution.',
                  style: TextStyle(
                      color: const Color(0xFF9A3412)
                          .withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _catColor(String cat) {
    switch (cat) {
      case 'Setup':
        return const Color(0xFFF97316);
      case 'Equipment':
        return const Color(0xFF0F766E);
      case 'Technology':
        return const Color(0xFF059669);
      case 'Inventory':
        return const Color(0xFFB45309);
      case 'Vehicle':
        return const Color(0xFFDC2626);
      case 'Marketing':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF98A2B3);
    }
  }
}

class _Mini extends StatelessWidget {
  const _Mini({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        '$label: $value',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color ?? const Color(0xFF475467)),
      ),
    );
  }
}
