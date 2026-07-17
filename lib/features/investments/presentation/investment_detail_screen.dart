import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../core/widgets/async_action_state.dart';
import '../models/investment_item.dart';
import '../providers/investment_item_providers.dart';
import 'investment_form_sheet.dart';

class InvestmentDetailScreen extends ConsumerStatefulWidget {
  const InvestmentDetailScreen({super.key, required this.investment});
  final InvestmentItem investment;

  @override
  ConsumerState<InvestmentDetailScreen> createState() => _InvestmentDetailScreenState();
}

class _InvestmentDetailScreenState extends ConsumerState<InvestmentDetailScreen>
    with AsyncActionState<InvestmentDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final inv = widget.investment;
    final outstanding = inv.amount - inv.returnAmount;
    final isPositive = inv.roi >= 0;
    final colors = Theme.of(context).colorScheme;

    return withLoadingOverlay(
      Scaffold(
        appBar: AppBar(
          title: Text(inv.title),
          actions: [
            IconButton(
              tooltip: 'Edit investment',
              onPressed: () => _openEditInvestment(inv),
              icon: const Icon(Icons.edit_rounded),
            ),
            IconButton(
              tooltip: 'Delete investment',
              onPressed: () => _confirmDelete(inv),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: _categoryColor(inv.category).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _categoryIcon(inv.category),
                            color: _categoryColor(inv.category),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                inv.title,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _categoryColor(inv.category).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  inv.category,
                                  style: TextStyle(
                                    color: _categoryColor(inv.category),
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
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _MiniMetric(
                          label: 'Invested',
                          value: money(inv.amount),
                          color: colors.primary,
                        ),
                        const SizedBox(width: 10),
                        _MiniMetric(
                          label: 'Returns',
                          value: money(inv.returnAmount),
                          color: colors.secondary,
                        ),
                        const SizedBox(width: 10),
                        _MiniMetric(
                          label: 'ROI',
                          value: '${inv.roi.toStringAsFixed(1)}%',
                          color: isPositive ? const Color(0xFF047857) : colors.error,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Investment Details',
              children: [
                _DetailRow(label: 'Category', value: inv.category),
                _DetailRow(label: 'Investor', value: inv.investorName.isEmpty ? 'N/A' : inv.investorName),
                _DetailRow(label: 'Date', value: '${inv.date.day}/${inv.date.month}/${inv.date.year}'),
                _DetailRow(label: 'Status', value: inv.status == 'active' ? 'Active' : 'Closed'),
                if (inv.description.isNotEmpty)
                  _DetailRow(label: 'Description', value: inv.description),
                if (inv.notes.isNotEmpty)
                  _DetailRow(label: 'Notes', value: inv.notes, showDivider: false),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Financial Summary',
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _BalanceTile(
                        label: 'Invested Amount',
                        value: money(inv.amount),
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _BalanceTile(
                        label: 'Return Amount',
                        value: money(inv.returnAmount),
                        color: colors.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: outstanding > 0
                        ? colors.error.withValues(alpha: 0.08)
                        : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        outstanding > 0 ? 'Outstanding Capital' : 'Fully Returned',
                        style: TextStyle(
                          color: outstanding > 0 ? colors.error : const Color(0xFF047857),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        money(outstanding),
                        style: TextStyle(
                          color: outstanding > 0 ? colors.error : const Color(0xFF047857),
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isPositive
                        ? const Color(0xFFF0FDF4)
                        : colors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        color: isPositive ? const Color(0xFF047857) : colors.error,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'ROI: ${inv.roi.toStringAsFixed(2)}% ${isPositive ? '(Profit)' : '(Loss)'}',
                        style: TextStyle(
                          color: isPositive ? const Color(0xFF047857) : colors.error,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      label: 'Processing...',
    );
  }

  void _openEditInvestment(InvestmentItem investment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InvestmentFormSheet(investment: investment),
    );
  }

  Future<void> _confirmDelete(InvestmentItem investment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Investment'),
        content: Text('Delete "${investment.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () async {
              await ref.read(investmentItemServiceProvider).delete(investment.investmentId);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (ctx.mounted) Navigator.of(ctx).pop(true);
              });
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pop();
    }
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

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
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
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF101828),
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

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
