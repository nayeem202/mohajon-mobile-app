import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/utils/money.dart';
import '../../../core/widgets/async_action_state.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';
import '../models/expense.dart';
import '../providers/expense_providers.dart';
import 'add_expense_sheet.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen>
    with SingleTickerProviderStateMixin, AsyncActionState<ExpensesScreen> {
  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    Future.microtask(() => ref.read(expenseServiceProvider).seedDemoExpenses());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(expenseDashboardProvider);
    final months = ref.watch(expenseMonthsProvider);
    final categories = ref.watch(expenseCategoriesProvider);
    final selectedMonth = ref.watch(expenseMonthFilterProvider);

    return withLoadingOverlay(
      Scaffold(
        backgroundColor: const Color(0xFFFFF8F1),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: isBusy ? null : () => Navigator.of(context).pop(),
          ),
        title: const Text(
          'Expenses',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        actions: const [
          NotificationBell(),
          SizedBox(width: 4),
          ShopAvatar(
            radius: 16,
            backgroundColor: Color(0xFFF97316),
            textColor: Colors.white,
          ),
          SizedBox(width: 8),
        ],
      ),
      body: FadeTransition(
        opacity: _fade,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _SummaryCards(data: dashboard),
            const SizedBox(height: 14),
            _MonthSelector(
              months: months,
              selectedMonth: selectedMonth,
              onChanged: (value) {
                if (value != null) {
                  ref.read(expenseMonthFilterProvider.notifier).state = value;
                }
              },
            ),
            const SizedBox(height: 14),
            _CategoryBreakdownCard(data: dashboard),
            const SizedBox(height: 14),
            _CategoryChips(
              categories: categories,
              selectedId: dashboard.selectedCategoryId,
              onChanged: (value) {
                ref.read(expenseCategoryFilterProvider.notifier).state = value;
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Expense List',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF101828),
                    ),
                  ),
                ),
                Text(
                  '${dashboard.filteredEntries.length} items',
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (dashboard.filteredEntries.isEmpty)
              const EmptyState(
                message: 'No expenses found for this month and filter.',
                icon: Remix.wallet_3_line,
              )
            else
              ...dashboard.filteredEntries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ExpenseItemCard(
                    entry: entry,
                    category: _categoryFor(categories, entry.categoryId),
                    onEdit: () => _openEditSheet(entry),
                    onDelete: () => _confirmDelete(entry),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const AddExpenseSheet(),
          );
        },
        backgroundColor: const Color(0xFFF97316),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      bottomNavigationBar: _StickyTotalBar(
        monthLabel: formatMonth(dashboard.selectedMonth),
        categoryLabel: _filterLabel(categories, dashboard.selectedCategoryId),
        total: dashboard.filteredTotal,
      ),
      ),
      label: 'Deleting expense...',
    );
  }

  ExpenseCategory _categoryFor(List<ExpenseCategory> categories, String id) {
    return categories.firstWhere(
      (category) => category.id == id,
      orElse: () => categories.first,
    );
  }

  String _filterLabel(List<ExpenseCategory> categories, String categoryId) {
    if (categoryId.isEmpty) return 'All categories';
    return categories
        .firstWhere(
          (category) => category.id == categoryId,
          orElse: () => categories.first,
        )
        .label;
  }

  void _openEditSheet(Expense expense) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddExpenseSheet(expense: expense),
    );
  }

  Future<void> _confirmDelete(Expense expense) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete expense?'),
          content: Text(
            'This will remove "${expense.description}" from the list.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (shouldDelete != true) return;

    await runBusyAction(
      () => ref.read(expenseServiceProvider).deleteExpense(expense.expenseId),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.data});

  final ExpenseDashboardData data;

  @override
  Widget build(BuildContext context) {
    final isCurrentMonth = _isCurrentMonth(data.selectedMonth);
    final selectedLabel = isCurrentMonth
        ? 'This Month'
        : DateFormat('MMM yyyy').format(data.selectedMonth);
    final previousLabel = isCurrentMonth
        ? 'Last Month'
        : DateFormat('MMM yyyy').format(data.previousMonth);
    final trend = data.selectedMonthTotal == data.previousMonthTotal
        ? _TrendDirection.flat
        : (data.selectedMonthTotal > data.previousMonthTotal
            ? _TrendDirection.up
            : _TrendDirection.down);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
                  color: const Color(0xFFF97316).withValues(alpha: 0.22),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedLabel,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  money(data.selectedMonthTotal),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Selected period expenses',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
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
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  previousLabel,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  money(data.previousMonthTotal),
                  style: const TextStyle(
                    color: Color(0xFF101828),
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                _TrendChip(
                  trend: trend,
                  percent: data.comparisonPercent.abs(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TrendChip extends StatelessWidget {
  const _TrendChip({
    required this.trend,
    required this.percent,
  });

  final _TrendDirection trend;
  final double percent;

  @override
  Widget build(BuildContext context) {
    final color = switch (trend) {
      _TrendDirection.up => const Color(0xFFDC2626),
      _TrendDirection.down => const Color(0xFF047857),
      _TrendDirection.flat => const Color(0xFF667085),
    };
    final icon = switch (trend) {
      _TrendDirection.up => Remix.arrow_up_s_line,
      _TrendDirection.down => Remix.arrow_down_s_line,
      _TrendDirection.flat => Remix.subtract_line,
    };
    final label = switch (trend) {
      _TrendDirection.up => 'Up',
      _TrendDirection.down => 'Down',
      _TrendDirection.flat => 'Flat',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            '$label ${percent.toStringAsFixed(1)}%',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

enum _TrendDirection { up, down, flat }

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.months,
    required this.selectedMonth,
    required this.onChanged,
  });

  final List<DateTime> months;
  final DateTime selectedMonth;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<DateTime>(
      value: selectedMonth,
      decoration: const InputDecoration(
        labelText: 'Month',
        prefixIcon: Icon(Icons.date_range_rounded),
      ),
      items: months
          .map(
            (month) => DropdownMenuItem(
              value: month,
              child: Text(formatMonth(month)),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _CategoryBreakdownCard extends StatelessWidget {
  const _CategoryBreakdownCard({required this.data});

  final ExpenseDashboardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8DDD2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Category Breakdown',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF101828),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Share of total expenses for the selected month',
            style: const TextStyle(
              color: Color(0xFF667085),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          if (data.breakdown.isEmpty)
            const Text(
              'No category data available.',
              style: TextStyle(color: Color(0xFF98A2B3)),
            )
          else
            ...data.breakdown.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _BreakdownRow(item: item),
              ),
            ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.item});

  final ExpenseCategoryBreakdown item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final barWidth = (width - 16 * 2 - 16 * 2 - 76) * (item.percent / 100);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: item.category.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                item.category.icon,
                color: item.category.color,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.category.label,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: Color(0xFF101828),
                ),
              ),
            ),
            Text(
              '${item.percent.toStringAsFixed(0)}%',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              money(item.amount),
              style: const TextStyle(
                color: Color(0xFF101828),
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFFF2E8DE),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Container(
              height: 8,
              width: barWidth.clamp(6.0, double.infinity).toDouble(),
              decoration: BoxDecoration(
                color: item.category.color,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selectedId,
    required this.onChanged,
  });

  final List<ExpenseCategory> categories;
  final String selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterChip(
            label: 'All',
            selected: selectedId.isEmpty,
            onTap: () => onChanged(''),
          ),
          const SizedBox(width: 8),
          for (final category in categories) ...[
            _FilterChip(
              label: category.label,
              selected: selectedId == category.id,
              onTap: () => onChanged(category.id),
            ),
            const SizedBox(width: 8),
          ],
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
    final colors = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      backgroundColor: Colors.white,
      selectedColor: colors.primary.withValues(alpha: 0.12),
      labelStyle: TextStyle(
        color: selected ? colors.primary : const Color(0xFF475467),
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      side: BorderSide(
        color: selected ? colors.primary.withValues(alpha: 0.24) : const Color(0xFFE8DDD2),
      ),
    );
  }
}

class _ExpenseItemCard extends StatelessWidget {
  const _ExpenseItemCard({
    required this.entry,
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  final Expense entry;
  final ExpenseCategory category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8DDD2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: category.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(category.icon, color: category.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF101828),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.categoryLabel.isNotEmpty ? entry.categoryLabel : category.label,
                  style: TextStyle(
                    color: category.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Remix.calendar_2_line,
                      size: 14,
                      color: Color(0xFF98A2B3),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('dd MMM yyyy').format(entry.date),
                      style: const TextStyle(
                        color: Color(0xFF98A2B3),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (entry.notes.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      const Icon(
                        Remix.file_text_line,
                        size: 14,
                        color: Color(0xFF98A2B3),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          entry.notes,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF98A2B3),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 18),
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                money(entry.amount),
                style: const TextStyle(
                  color: Color(0xFF101828),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StickyTotalBar extends StatelessWidget {
  const _StickyTotalBar({
    required this.monthLabel,
    required this.categoryLabel,
    required this.total,
  });

  final String monthLabel;
  final String categoryLabel;
  final double total;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: const Color(0xFFE8DDD2))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF97316).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Remix.wallet_3_line,
                color: Color(0xFFF97316),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$monthLabel total',
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    categoryLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF101828),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              money(total),
              style: const TextStyle(
                color: Color(0xFFF97316),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _isCurrentMonth(DateTime value) {
  final now = DateTime.now();
  return value.year == now.year && value.month == now.month;
}
