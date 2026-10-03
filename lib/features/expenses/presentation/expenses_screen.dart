import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/async_action_state.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';
import '../models/expense.dart';
import '../providers/expense_providers.dart';
import '../../subscription/services/paywall_gate.dart';
import 'expense_form_screen.dart';

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
    final l10n = AppLocalizations.of(context);

    return withLoadingOverlay(
      Theme(
        data: MohajonWarm.theme(Theme.of(context)),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: MohajonWarm.pageGradient,
            ),
            child: SafeArea(
              child: FadeTransition(
                opacity: _fade,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                  children: [
                    _ExpensesHeader(
                      onBack: isBusy
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 18),
                    _SummaryCards(data: dashboard),
                    const SizedBox(height: 14),
                    _MonthSelector(
                      months: months,
                      selectedMonth: selectedMonth,
                      onChanged: (value) {
                        if (value != null) {
                          ref
                              .read(expenseMonthFilterProvider.notifier)
                              .state = value;
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
                        ref
                            .read(expenseCategoryFilterProvider.notifier)
                            .state = value;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        SizedBox(
                          child: Text(
                            l10n.t('expenseList'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                              color: MohajonWarm.ink,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: MohajonWarm.primary.withValues(
                              alpha: 0.22,
                            ),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: MohajonWarm.primary.withValues(
                                alpha: 0.35,
                              ),
                            ),
                          ),
                          child: Text(
                            l10n.tP(
                              'expenseItems',
                              {'n': dashboard.filteredEntries.length.toString()},
                            ),
                            style: const TextStyle(
                              color: Color(0xFF5D4A00),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (dashboard.filteredEntries.isEmpty)
                      EmptyState(
                        message: l10n.t('noExpensesFound'),
                        icon: Remix.wallet_3_line,
                      )
                    else
                      ...dashboard.filteredEntries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ExpenseItemCard(
                            entry: entry,
                            category: _categoryFor(
                              categories,
                              entry.categoryId,
                            ),
                            onEdit: () => _openForm(entry),
                            onDelete: () => _confirmDelete(entry),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openForm(null),
            child: const Icon(Icons.add_rounded, size: 26),
          ),
          bottomNavigationBar: _StickyTotalBar(
            monthLabel: formatMonth(dashboard.selectedMonth),
            categoryLabel: _filterLabel(
              categories,
              dashboard.selectedCategoryId,
              l10n,
            ),
            total: dashboard.filteredTotal,
          ),
        ),
      ),
      label: l10n.t('deletingExpense'),
    );
  }

  ExpenseCategory _categoryFor(List<ExpenseCategory> categories, String id) {
    return categories.firstWhere(
      (category) => category.id == id,
      orElse: () => categories.first,
    );
  }

  String _filterLabel(
    List<ExpenseCategory> categories,
    String categoryId,
    AppLocalizations l10n,
  ) {
    if (categoryId.isEmpty) return l10n.t('allCategories');
    return _expenseCategoryLabel(
      categories
          .firstWhere(
            (category) => category.id == categoryId,
            orElse: () => categories.first,
          )
          .label,
      l10n,
    );
  }

  void _openForm(Expense? expense) {
    PaywallGate.guard(
      context,
      ref,
      () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ExpenseFormScreen(expense: expense)),
      ),
    );
  }

  Future<void> _confirmDelete(Expense expense) async {
    final dl10n = AppLocalizations.of(context);
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return PopScope(
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFEBEE),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFFEF5350),
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      dl10n.t('deleteExpenseQuestion'),
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1C1917),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        dl10n.tP('deleteExpenseConfirm', {
                          'desc': expense.description,
                        }),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF98A2B3),
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 40,
                            child: OutlinedButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(false),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: const Color(0xFFF0ECE6),
                                foregroundColor: const Color(0xFF525252),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide.none,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              child: Text(dl10n.t('cancel')),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 40,
                            child: FilledButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(true),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFEF5350),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: Text(dl10n.t('delete')),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    if (shouldDelete != true) return;

    await runBusyAction(
      () => ref.read(expenseServiceProvider).deleteExpense(expense.expenseId),
    );
  }
}

class _ExpensesHeader extends StatelessWidget {
  const _ExpensesHeader({required this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IconTheme(
      data: const IconThemeData(color: MohajonWarm.ink),
      child: Row(
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
              Icons.wallet_rounded,
              color: MohajonWarm.ink,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('expenses'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: MohajonWarm.ink,
                  ),
                ),
                Text(
                  l10n.t('trackShopSpending'),
                  style: const TextStyle(
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
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.data});

  final ExpenseDashboardData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isCurrentMonth = _isCurrentMonth(data.selectedMonth);
    final selectedLabel = isCurrentMonth
        ? l10n.t('thisMonth')
        : DateFormat('MMM yyyy').format(data.selectedMonth);
    final previousLabel = isCurrentMonth
        ? l10n.t('lastMonth')
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
              color: MohajonWarm.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: MohajonWarm.goldBorder),
              boxShadow: [
                BoxShadow(
                  color: MohajonWarm.primary.withValues(alpha: 0.20),
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
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: MohajonWarm.tintYellow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.calendar_month_rounded,
                        color: MohajonWarm.goldText,
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        selectedLabel.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: MohajonWarm.goldText,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    money(data.selectedMonthTotal),
                    maxLines: 1,
                    style: const TextStyle(
                      color: MohajonWarm.ink,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.t('selectedPeriodExpenses'),
                  style: const TextStyle(
                    color: MohajonWarm.muted,
                    fontSize: 11,
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
            padding: const EdgeInsets.all(16),
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
                  color: MohajonWarm.primary.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  previousLabel,
                  style: const TextStyle(
                    color: MohajonWarm.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    money(data.previousMonthTotal),
                    maxLines: 1,
                    style: const TextStyle(
                      color: MohajonWarm.ink,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
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
    final l10n = AppLocalizations.of(context);
    final color = switch (trend) {
      _TrendDirection.up => MohajonWarm.red,
      _TrendDirection.down => MohajonWarm.green,
      _TrendDirection.flat => MohajonWarm.muted,
    };
    final background = switch (trend) {
      _TrendDirection.up => MohajonWarm.tintRed,
      _TrendDirection.down => MohajonWarm.tintGreen,
      _TrendDirection.flat => MohajonWarm.tintYellow,
    };
    final icon = switch (trend) {
      _TrendDirection.up => Remix.arrow_up_s_line,
      _TrendDirection.down => Remix.arrow_down_s_line,
      _TrendDirection.flat => Remix.subtract_line,
    };
    final label = switch (trend) {
      _TrendDirection.up => l10n.t('up'),
      _TrendDirection.down => l10n.t('down'),
      _TrendDirection.flat => l10n.t('flat'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 4),
          Text(
            '$label ${percent.toStringAsFixed(1)}%',
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
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
    return DropdownButtonHideUnderline(
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: MohajonWarm.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MohajonWarm.goldBorder),
          boxShadow: [
            BoxShadow(
              color: MohajonWarm.ink.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: DropdownButton<DateTime>(
          value: selectedMonth,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: MohajonWarm.muted,
          ),
          dropdownColor: Colors.white,
          style: const TextStyle(
            color: MohajonWarm.ink,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          underline: const SizedBox.shrink(),
          items: months
              .map(
                (month) => DropdownMenuItem(
                  value: month,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        size: 18,
                        color: MohajonWarm.muted,
                      ),
                      const SizedBox(width: 10),
                      Text(formatMonth(month)),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _CategoryBreakdownCard extends StatelessWidget {
  const _CategoryBreakdownCard({required this.data});

  final ExpenseDashboardData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
          Text(
            l10n.t('categoryBreakdown'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
              color: MohajonWarm.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.t('categoryBreakdownSubtitle'),
            style: const TextStyle(
              color: MohajonWarm.muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          if (data.breakdown.isEmpty)
            Text(
              l10n.t('noCategoryData'),
              style: const TextStyle(
                color: MohajonWarm.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            ...data.breakdown.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _BreakdownRow(item: item, l10n: l10n),
              ),
            ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.item, required this.l10n});

  final ExpenseCategoryBreakdown item;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final barWidth = (width - 18 * 2 - 16 * 2 - 76) * (item.percent / 100);

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
                _expenseCategoryLabel(item.category.label, l10n),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: MohajonWarm.ink,
                ),
              ),
            ),
            Text(
              '${item.percent.toStringAsFixed(0)}%',
              style: const TextStyle(
                color: MohajonWarm.muted,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              money(item.amount),
              style: const TextStyle(
                color: MohajonWarm.ink,
                fontWeight: FontWeight.w900,
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
                color: const Color(0xFFFFF0A6),
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
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterChip(
            label: l10n.t('all'),
            selected: selectedId.isEmpty,
            onTap: () => onChanged(''),
          ),
          const SizedBox(width: 8),
          for (final category in categories) ...[
            _FilterChip(
              label: _expenseCategoryLabel(category.label, l10n),
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

/// Pill chip matching the Stock filter chips.
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
    return Material(
      color: selected ? MohajonWarm.primary : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? MohajonWarm.primary.withValues(alpha: 0.45)
                  : MohajonWarm.goldBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFF5D4A00) : MohajonWarm.muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
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
    final l10n = AppLocalizations.of(context);
    return Material(
      color: MohajonWarm.card,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: MohajonWarm.goldBorder),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: MohajonWarm.ink.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
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
                      fontWeight: FontWeight.w900,
                      color: MohajonWarm.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _expenseCategoryLabel(
                      entry.categoryLabel.isNotEmpty
                          ? entry.categoryLabel
                          : category.label,
                      l10n,
                    ),
                    style: TextStyle(
                      color: category.color,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Remix.calendar_2_line,
                        size: 14,
                        color: MohajonWarm.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd MMM yyyy').format(entry.date),
                        style: const TextStyle(
                          color: MohajonWarm.muted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (entry.notes.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        const Icon(
                          Remix.file_text_line,
                          size: 14,
                          color: MohajonWarm.muted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            entry.notes,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: MohajonWarm.muted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
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
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    size: 18,
                    color: MohajonWarm.muted,
                  ),
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text(l10n.t('edit')),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(l10n.t('delete')),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  money(entry.amount),
                  style: const TextStyle(
                    color: MohajonWarm.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
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
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: MohajonWarm.card,
          border: const Border(
            top: BorderSide(color: MohajonWarm.goldBorder),
          ),
          boxShadow: [
            BoxShadow(
              color: MohajonWarm.ink.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MohajonWarm.goldBorder),
              ),
              child: const Icon(
                Remix.wallet_3_line,
                color: MohajonWarm.goldText,
                size: 19,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.tP('monthTotal', {'month': monthLabel}),
                    style: const TextStyle(
                      color: MohajonWarm.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    categoryLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: MohajonWarm.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              money(total),
              style: const TextStyle(
                color: MohajonWarm.goldText,
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

String _expenseCategoryLabel(String label, AppLocalizations l10n) {
  return switch (label) {
    'Rent' => l10n.t('catRent'),
    'Electricity' => l10n.t('catElectricity'),
    'Salaries' => l10n.t('catSalaries'),
    'Transport' => l10n.t('catTransport'),
    'Maintenance' => l10n.t('catMaintenance'),
    'Miscellaneous' => l10n.t('catMisc'),
    _ => label,
  };
}
