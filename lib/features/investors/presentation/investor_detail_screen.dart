import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../investments/models/payout.dart';
import '../../investments/providers/investment_providers.dart';
import '../models/investor.dart';
import '../providers/investor_providers.dart';
import 'investor_form_sheet.dart';

class InvestorDetailScreen extends ConsumerStatefulWidget {
  const InvestorDetailScreen({super.key, required this.investorId});

  final String investorId;

  @override
  ConsumerState<InvestorDetailScreen> createState() =>
      _InvestorDetailScreenState();
}

class _InvestorDetailScreenState extends ConsumerState<InvestorDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final investorsAsync = ref.watch(investorsStreamProvider);
    final payoutsAsync =
        ref.watch(investorPayoutsStreamProvider(widget.investorId));
    final payouts = payoutsAsync.value ?? [];

    return Scaffold(
      body: investorsAsync.when(
        data: (investors) {
          final investor =
              investors.where((i) => i.id == widget.investorId).firstOrNull;
          if (investor == null) {
            return const Center(child: Text('Investor not found'));
          }
          return _buildDetail(investor, payouts);
        },
        error: (e, _) => Center(child: Text('Error: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildDetail(Investor investor, List<Payout> payouts) {
    final colors = Theme.of(context).colorScheme;
    final financials = ref.watch(investorFinancialsProvider(investor.id));

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 160,
          pinned: true,
          actions: [
            IconButton(
              tooltip: 'Update investor',
              icon: const Icon(Icons.edit_rounded),
              onPressed: () => _openEditForm(investor),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.primary.withValues(alpha: 0.8),
                    colors.primary.withValues(alpha: 0.2),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: colors.surface.withValues(alpha: 0.3),
                    backgroundImage: investor.photoUrl.isNotEmpty
                        ? NetworkImage(investor.photoUrl)
                        : null,
                    child: investor.photoUrl.isEmpty
                        ? Text(
                            investor.name.isNotEmpty
                                ? investor.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: colors.onPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 24,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    investor.name,
                    style: TextStyle(
                      color: colors.onPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  if (investor.phone.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 12),
                      child: Text(
                        investor.phone,
                        style: TextStyle(
                          color: colors.onPrimary.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FinancialSummary(financials: financials),
                const SizedBox(height: 16),
                if (investor.email.isNotEmpty ||
                    investor.address.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border.all(color: colors.outlineVariant),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Contact Info',
                          style: TextStyle(fontWeight: FontWeight.w900,
                              color: colors.onSurface)),
                        const SizedBox(height: 8),
                        if (investor.email.isNotEmpty)
                          _InfoRow(label: 'Email', value: investor.email),
                        if (investor.address.isNotEmpty)
                          _InfoRow(label: 'Address', value: investor.address),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (investor.notes.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border.all(color: colors.outlineVariant),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Notes',
                          style: TextStyle(fontWeight: FontWeight.w900,
                              color: colors.onSurface)),
                        const SizedBox(height: 8),
                        Text(investor.notes,
                          style: TextStyle(color: colors.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text('RECENT PAYOUTS',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                if (payouts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text('No payouts yet.',
                          style: TextStyle(color: colors.outline)),
                    ),
                  )
                else
                  ...payouts.take(10).map((p) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          border: Border.all(color: colors.outlineVariant),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_rounded,
                                size: 18, color: const Color(0xFF047857)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                p.note.isNotEmpty ? p.note : 'Payout',
                                style:
                                    TextStyle(fontWeight: FontWeight.w600, color: colors.onSurface),
                              ),
                            ),
                            Text(
                              money(p.amount),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: colors.onSurface,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${p.createdAt.day}/${p.createdAt.month}/${p.createdAt.year}',
                              style: TextStyle(
                                color: colors.outline,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _openEditForm(Investor investor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InvestorFormSheet(investor: investor),
    );
  }
}

class _FinancialSummary extends StatelessWidget {
  const _FinancialSummary({required this.financials});
  final InvestorFinancials financials;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _SummaryBox(
                label: 'Total Invested',
                value: money(financials.investment),
                color: colors.primary,
              ),
              const SizedBox(width: 8),
              _SummaryBox(
                label: 'Total Profit',
                value: money(financials.profit),
                color: colors.secondary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _SummaryBox(
                label: 'Total Loss',
                value: money(financials.loss),
                color: colors.error,
              ),
              const SizedBox(width: 8),
              _SummaryBox(
                label: 'Outstanding',
                value: money(financials.outstanding),
                color: financials.outstanding > 0
                    ? colors.error
                    : colors.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryBox extends StatelessWidget {
  const _SummaryBox({
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

@override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(label,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
