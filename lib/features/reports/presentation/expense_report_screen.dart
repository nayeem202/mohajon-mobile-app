import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';
import '../../expenses/models/expense.dart';
import '../../expenses/providers/expense_providers.dart';
import '../services/expense_report_excel_service.dart';
import '../services/expense_report_pdf_service.dart';

class ExpenseReportScreen extends ConsumerStatefulWidget {
  const ExpenseReportScreen({super.key});

  @override
  ConsumerState<ExpenseReportScreen> createState() =>
      _ExpenseReportScreenState();
}

class _ExpenseReportScreenState extends ConsumerState<ExpenseReportScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late DateTimeRange _range;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = _monthRange(now);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
      initialDateRange: _range,
      helpText: 'Select expense date range',
      saveText: 'Apply',
    );
    if (picked == null) return;
    setState(() => _range = picked);
  }

  void _setPreset(DateTimeRange range) {
    setState(() => _range = range);
  }

  Future<void> _exportXlsx(List<Expense> expenses) async {
    if (expenses.isEmpty) return;
    final service = ExpenseReportExcelService();
    await service.saveExpenseReport(expenses: expenses, range: _range);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Expense report exported as XLSX')),
    );
  }

  Future<void> _exportPdf(List<Expense> expenses) async {
    if (expenses.isEmpty) return;
    final service = ExpenseReportPdfService();
    await service.saveExpenseReport(expenses: expenses, range: _range);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Expense report exported as PDF')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allExpenses = ref.watch(expensesProvider).value ?? const <Expense>[];
    final categories = ref.watch(expenseCategoriesProvider);
    final selectedExpenses = _filterExpenses(allExpenses);
    final total = selectedExpenses.fold<double>(0, (sum, item) => sum + item.amount);
    final average = selectedExpenses.isEmpty ? 0.0 : total / selectedExpenses.length;
    final highestCategory = _highestCategoryLabel(selectedExpenses);
    final categoryCount = selectedExpenses
        .map((expense) => expense.categoryId)
        .toSet()
        .length;

    return Theme(
      data: MohajonWarm.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Expense Report',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: MohajonWarm.ink,
            ),
          ),
          backgroundColor: MohajonWarm.primary,
          foregroundColor: MohajonWarm.ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: MohajonWarm.primary,
            statusBarIconBrightness: Brightness.dark,
          ),
          actions: [
            const NotificationBell(),
            const SizedBox(width: 4),
            const ShopAvatar(
              radius: 16,
              backgroundColor: MohajonWarm.primary,
              textColor: MohajonWarm.ink,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: MohajonWarm.pageGradient),
          child: SafeArea(
            top: false,
            child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOut,
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    label: 'Total Expense',
                    value: money(total),
                    valueColor: const Color(0xFFF97316),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryCard(
                    label: 'Entries',
                    value: '${selectedExpenses.length}',
                    valueColor: MohajonWarm.goldText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    label: 'Average',
                    value: money(average),
                    valueColor: const Color(0xFFF97316),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryCard(
                    label: 'Categories',
                    value: '$categoryCount',
                    valueColor: MohajonWarm.goldText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _RangeSelector(
              range: _range,
              onPickRange: _pickRange,
              onThisMonth: () => _setPreset(_monthRange(DateTime.now())),
              onLastMonth: () => _setPreset(_previousMonthRange(DateTime.now())),
              onLast30Days: () => _setPreset(_last30DaysRange(DateTime.now())),
            ),
            const SizedBox(height: 8),
            Text(
              'Top category: $highestCategory',
              style: const TextStyle(
                color: MohajonWarm.goldText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _FullExportButton(
                    label: 'Download XLSX',
                    icon: Icons.table_chart_outlined,
                    color: const Color(0xFF059669),
                    onTap: () => _exportXlsx(selectedExpenses),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _FullExportButton(
                    label: 'Download PDF',
                    icon: Icons.picture_as_pdf_rounded,
                    color: const Color(0xFFF97316),
                    onTap: () => _exportPdf(selectedExpenses),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
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
                  '${selectedExpenses.length} items',
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${DateFormat('dd MMM yyyy').format(_range.start)} - ${DateFormat('dd MMM yyyy').format(_range.end)}',
              style: const TextStyle(
                color: Color(0xFF667085),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            if (selectedExpenses.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(
                  child: Text(
                    'No expenses found for this date range.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF98A2B3),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
            else
              ...selectedExpenses.map(
                (expense) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ExpenseCard(
                    expense: expense,
                    category: _categoryFor(categories, expense.categoryId),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            _ListFooter(total: total, count: selectedExpenses.length),
          ],
        ),
        ),
        ),
      ),
      ),
    );
  }

  List<Expense> _filterExpenses(List<Expense> expenses) {
    final start = DateTime(
      _range.start.year,
      _range.start.month,
      _range.start.day,
    );
    final endExclusive = DateTime(
      _range.end.year,
      _range.end.month,
      _range.end.day,
    ).add(const Duration(days: 1));

    final filtered = expenses.where((expense) {
      return !expense.date.isBefore(start) && expense.date.isBefore(endExclusive);
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return filtered;
  }

  ExpenseCategory _categoryFor(List<ExpenseCategory> categories, String id) {
    return categories.firstWhere(
      (category) => category.id == id,
      orElse: () => categories.first,
    );
  }

  String _highestCategoryLabel(List<Expense> expenses) {
    if (expenses.isEmpty) return 'None';
    final grouped = <String, double>{};
    for (final expense in expenses) {
      grouped[expense.categoryLabel.isNotEmpty
              ? expense.categoryLabel
              : expense.categoryId] =
          (grouped[expense.categoryLabel.isNotEmpty
                  ? expense.categoryLabel
                  : expense.categoryId] ??
              0) +
              expense.amount;
    }
    final top = grouped.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return top.first.key;
  }

  static DateTimeRange _monthRange(DateTime value) {
    final start = DateTime(value.year, value.month, 1);
    final end = DateTime(value.year, value.month + 1, 0);
    return DateTimeRange(start: start, end: end);
  }

  static DateTimeRange _previousMonthRange(DateTime value) {
    final prev = DateTime(value.year, value.month - 1, 1);
    final end = DateTime(value.year, value.month, 0);
    return DateTimeRange(start: prev, end: end);
  }

  static DateTimeRange _last30DaysRange(DateTime value) {
    final end = DateTime(value.year, value.month, value.day);
    final start = end.subtract(const Duration(days: 29));
    return DateTimeRange(start: start, end: end);
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MohajonWarm.card, Color(0xFFFFFBEF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MohajonWarm.goldBorder),
        boxShadow: [
          BoxShadow(
            color: MohajonWarm.ink.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: MohajonWarm.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.range,
    required this.onPickRange,
    required this.onThisMonth,
    required this.onLastMonth,
    required this.onLast30Days,
  });

  final DateTimeRange range;
  final VoidCallback onPickRange;
  final VoidCallback onThisMonth;
  final VoidCallback onLastMonth;
  final VoidCallback onLast30Days;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MohajonWarm.card, Color(0xFFFFFBEF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MohajonWarm.goldBorder),
        boxShadow: [
          BoxShadow(
            color: MohajonWarm.ink.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Date Range',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: MohajonWarm.ink,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onPickRange,
                icon: const Icon(Icons.date_range_rounded,
                    size: 18, color: MohajonWarm.goldText),
                label: const Text('Change',
                    style: TextStyle(
                        color: MohajonWarm.goldText,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${DateFormat('dd MMM yyyy').format(range.start)}  -  ${DateFormat('dd MMM yyyy').format(range.end)}',
            style: const TextStyle(
              color: MohajonWarm.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _RangeChip(label: 'This Month', onTap: onThisMonth),
                const SizedBox(width: 8),
                _RangeChip(label: 'Last Month', onTap: onLastMonth),
                const SizedBox(width: 8),
                _RangeChip(label: 'Last 30 Days', onTap: onLast30Days),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      backgroundColor: MohajonWarm.tintYellow,
      side: const BorderSide(color: MohajonWarm.goldBorder),
      labelStyle: const TextStyle(
        color: MohajonWarm.goldText,
        fontWeight: FontWeight.w800,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({
    required this.expense,
    required this.category,
  });

  final Expense expense;
  final ExpenseCategory category;

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('dd MMM yyyy').format(expense.date);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MohajonWarm.card, Color(0xFFFFFBEF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MohajonWarm.goldBorder),
        boxShadow: [
          BoxShadow(
            color: MohajonWarm.ink.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [category.color, category.color.withValues(alpha: 0.6)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: category.color.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(category.icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.description,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF101828),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  expense.categoryLabel.isNotEmpty
                      ? expense.categoryLabel
                      : category.label,
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
                      dateText,
                      style: const TextStyle(
                        color: Color(0xFF98A2B3),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (expense.notes.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      const Icon(
                        Remix.file_text_line,
                        size: 14,
                        color: Color(0xFF98A2B3),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          expense.notes,
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
          Text(
            money(expense.amount),
            style: const TextStyle(
              color: MohajonWarm.goldText,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _FullExportButton extends StatelessWidget {
  const _FullExportButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({
    required this.total,
    required this.count,
  });

  final double total;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MohajonWarm.card, Color(0xFFFFFBEF)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MohajonWarm.goldBorder),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Selected range total',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF667085),
              ),
            ),
          ),
          Text(
            '$count items',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF101828),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            money(total),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFFF97316),
            ),
          ),
        ],
      ),
    );
  }
}
