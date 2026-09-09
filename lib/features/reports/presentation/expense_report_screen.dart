import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/pdf_doc.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';
import '../../expenses/models/expense.dart';
import '../../expenses/providers/expense_providers.dart';
import '../../settings/providers/shop_profile_providers.dart';
import '../services/expense_report_excel_service.dart';
import '../services/expense_report_pdf_service.dart';
import 'report_shared_widgets.dart';

class ExpenseReportScreen extends ConsumerStatefulWidget {
  const ExpenseReportScreen({super.key});

  @override
  ConsumerState<ExpenseReportScreen> createState() =>
      _ExpenseReportScreenState();
}

class _ExpenseReportScreenState extends ConsumerState<ExpenseReportScreen>
    with ReportExportMixin {
  late DateTimeRange _range;

  @override
  void initState() {
    super.initState();
    _range = reportMonthRange(DateTime.now());
  }

  Future<void> _pickRange() async {
    final l10n = AppLocalizations.of(context);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
      initialDateRange: _range,
      helpText: l10n.t('selectExpenseRange'),
      saveText: l10n.t('applyLabel'),
    );
    if (picked == null) return;
    setState(() => _range = picked);
  }

  Future<void> _exportXlsx(List<Expense> expenses) => runExport(
        isXlsx: true,
        task: () async {
          if (expenses.isEmpty) return;
          await ExpenseReportExcelService()
              .saveExpenseReport(expenses: expenses, range: _range);
        },
        message: AppLocalizations.of(context)
            .tP('exportedAsXlsx', {'report': AppLocalizations.of(context).t('reportExpense')}),
      );

  Future<void> _exportPdf(List<Expense> expenses) => runExport(
        isXlsx: false,
        task: () async {
          if (expenses.isEmpty) return;
          final company =
              DocCompany.fromShop(ref.read(shopProfileProvider).value);
          await ExpenseReportPdfService()
              .saveExpenseReport(expenses: expenses, range: _range, company: company);
        },
        message: AppLocalizations.of(context)
            .tP('exportedAsPdf', {'report': AppLocalizations.of(context).t('reportExpense')}),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
          title: Text(
            l10n.t('reportExpense'),
            style: const TextStyle(
              color: MohajonWarm.ink,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
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
          actions: const [
            NotificationBell(),
            SizedBox(width: 6),
            ShopAvatar(),
          ],
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: MohajonWarm.pageGradient),
          child: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ReportSummaryCard(
                        label: l10n.t('totalExpense'),
                        value: money(total),
                        valueColor: const Color(0xFF9A3412),
                        icon: Icons.receipt_long_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ReportSummaryCard(
                        label: l10n.t('entriesLabel'),
                        value: '${selectedExpenses.length}',
                        valueColor: MohajonWarm.goldText,
                        icon: Icons.list_alt_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ReportSummaryCard(
                        label: l10n.t('averageLabel'),
                        value: money(average),
                        valueColor: const Color(0xFFB45309),
                        icon: Icons.speed_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ReportSummaryCard(
                        label: l10n.t('categoriesLabel'),
                        value: '$categoryCount',
                        valueColor: const Color(0xFF059669),
                        icon: Icons.category_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ReportRangeSelector(
                  range: _range,
                  onPickRange: _pickRange,
                  onThisMonth: () =>
                      setState(() => _range = reportMonthRange(DateTime.now())),
                  onLastMonth: () => setState(
                    () => _range = reportPreviousMonthRange(DateTime.now()),
                  ),
                  onLast30Days: () => setState(
                    () => _range = reportLast30DaysRange(DateTime.now()),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ReportExportButton(
                        label: l10n.t('downloadXlsx'),
                        icon: Icons.table_chart_outlined,
                        color: const Color(0xFF059669),
                        isBusy: exportingXlsx,
                        onTap: () => _exportXlsx(selectedExpenses),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ReportExportButton(
                        label: l10n.t('downloadPdf'),
                        icon: Icons.picture_as_pdf_rounded,
                        color: const Color(0xFFF97316),
                        isBusy: exportingPdf,
                        onTap: () => _exportPdf(selectedExpenses),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _HighlightsRow(highestCategory: highestCategory),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [MohajonWarm.primary, MohajonWarm.primarySoft],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        size: 15,
                        color: MohajonWarm.ink,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      l10n.t('expenseList'),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.9,
                        color: Color(0x992F3028),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: MohajonWarm.tintYellow,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: MohajonWarm.goldBorder),
                      ),
                      child: Text(
                        l10n.tP('xItems', {'count': '${selectedExpenses.length}'}),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: MohajonWarm.goldText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  reportRangeLabel(_range),
                  style: const TextStyle(
                    color: MohajonWarm.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                if (selectedExpenses.isEmpty)
                  const _EmptyState()
                else
                  ...selectedExpenses.map(
                    (expense) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ExpenseRowTile(
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
}

class _HighlightsRow extends StatelessWidget {
  const _HighlightsRow({required this.highestCategory});

  final String highestCategory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MohajonWarm.primary.withValues(alpha: 0.1),
            MohajonWarm.primarySoft.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MohajonWarm.primary.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: MohajonWarm.primary.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [MohajonWarm.primary, MohajonWarm.primarySoft],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              size: 18,
              color: MohajonWarm.ink,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('topCategory'),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: MohajonWarm.muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  highestCategory,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: MohajonWarm.ink,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.auto_awesome_rounded,
            size: 18,
            color: MohajonWarm.goldText,
          ),
        ],
      ),
    );
  }
}

class _ExpenseRowTile extends StatelessWidget {
  const _ExpenseRowTile({
    required this.expense,
    required this.category,
  });

  final Expense expense;
  final ExpenseCategory category;

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('dd MMM yyyy').format(expense.date);
    final subtitle = expense.notes.isNotEmpty
        ? '$dateText  •  ${category.label}  •  ${expense.notes}'
        : '$dateText  •  ${category.label}';
    return ReportRowTile(
      icon: category.icon,
      iconColor: category.color,
      title: expense.description.isEmpty ? category.label : expense.description,
      subtitle: subtitle,
      trailing: money(expense.amount),
      trailingColor: MohajonWarm.goldText,
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
    final l10n = AppLocalizations.of(context);
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
        boxShadow: [
          BoxShadow(
            color: MohajonWarm.ink.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.t('selectedRangeTotal'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF667085),
              ),
            ),
          ),
          Text(
            l10n.tP('xItems', {'count': '$count'}),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF101828),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [MohajonWarm.orange, Color(0xFFF97316)],
              ),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF97316).withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              money(total),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: MohajonWarm.tintYellow,
              border: Border.all(color: MohajonWarm.goldBorder),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 40,
              color: MohajonWarm.goldText,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.t('noExpensesFound'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: MohajonWarm.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.t('noExpensesForRange'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: MohajonWarm.muted,
            ),
          ),
        ],
      ),
    );
  }
}