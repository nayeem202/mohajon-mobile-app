import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/sale.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';
import '../../customers/providers/customer_providers.dart';
import '../../expenses/models/expense.dart';
import '../../expenses/providers/expense_providers.dart';
import '../models/table_report.dart';
import '../services/profit_loss_excel_service.dart';
import '../services/profit_loss_pdf_service.dart';
import 'report_shared_widgets.dart';

class ProfitLossScreen extends ConsumerStatefulWidget {
  const ProfitLossScreen({super.key});

  @override
  ConsumerState<ProfitLossScreen> createState() => _ProfitLossScreenState();
}

class _ProfitLossScreenState extends ConsumerState<ProfitLossScreen>
    with ReportExportMixin {
  late DateTimeRange _range;

  @override
  void initState() {
    super.initState();
    _range = reportMonthRange(DateTime.now());
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
      initialDateRange: _range,
      helpText: 'Select profit & loss range',
      saveText: 'Apply',
    );
    if (picked == null) return;
    setState(() => _range = picked);
  }

  bool _inRange(DateTime value) {
    final end = _range.end;
    return !value.isBefore(_range.start) &&
        !value.isAfter(DateTime(end.year, end.month, end.day, 23, 59, 59));
  }

  ({double revenue, double cogs, double grossProfit, double expenses,
      double netProfit, ReportTableData table}) _compute() {
    final sales = ref.watch(salesStreamProvider).value ?? const <Sale>[];
    final allExpenses = ref.watch(expensesProvider).value ?? const <Expense>[];
    final selectedSales =
        sales.where((sale) => _inRange(sale.createdAt)).toList();
    final selectedExpenses =
        allExpenses.where((expense) => _inRange(expense.date)).toList();

    final revenue = selectedSales.fold<double>(
      0,
      (sum, sale) => sum + sale.totalAmount,
    );
    final cogs = selectedSales.fold<double>(
      0,
      (sum, sale) =>
          sum + sale.items.fold<double>(0, (acc, item) => acc + item.qty * item.purchasePrice),
    );
    final grossProfit = revenue - cogs;
    final expenses = selectedExpenses.fold<double>(
      0,
      (sum, expense) => sum + expense.amount,
    );
    final netProfit = grossProfit - expenses;

    final table = ReportTableData(
      title: 'Profit & Loss',
      subtitle: reportRangeLabel(_range),
      columns: const [
        ReportTableColumn(key: 'item', header: 'Item', weight: 2),
        ReportTableColumn(key: 'amount', header: 'Amount', rightAlign: true),
      ],
      rows: [
        {'item': 'Sales Revenue', 'amount': revenue},
        {'item': 'Cost of Goods Sold', 'amount': cogs},
        {'item': 'Gross Profit', 'amount': grossProfit},
        {'item': 'Operating Expenses', 'amount': expenses},
        {'item': 'Net Profit', 'amount': netProfit},
      ],
    );

    return (
      revenue: revenue,
      cogs: cogs,
      grossProfit: grossProfit,
      expenses: expenses,
      netProfit: netProfit,
      table: table,
    );
  }

  Future<void> _exportXlsx() => runExport(
        task: () async {
          final data = _compute();
          await ProfitLossExcelService()
              .saveProfitLoss(table: data.table, range: _range);
        },
        message: 'Profit & Loss exported as XLSX',
      );

  Future<void> _exportPdf() => runExport(
        task: () async {
          final data = _compute();
          await ProfitLossPdfService()
              .saveProfitLoss(table: data.table, range: _range);
        },
        message: 'Profit & Loss exported as PDF',
      );

  @override
  Widget build(BuildContext context) {
    final data = _compute();
    final profitable = data.netProfit >= 0;

    return Theme(
      data: MohajonWarm.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Profit & Loss',
            style: TextStyle(
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
                  label: 'Revenue',
                  value: money(data.revenue),
                  valueColor: MohajonWarm.goldText,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ReportSummaryCard(
                  label: 'Gross Profit',
                  value: money(data.grossProfit),
                  valueColor: const Color(0xFF059669),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ReportSummaryCard(
                  label: 'Operating Expenses',
                  value: money(data.expenses),
                  valueColor: const Color(0xFFF97316),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ReportSummaryCard(
                  label: 'Net Profit',
                  value: money(data.netProfit),
                  valueColor: profitable
                      ? const Color(0xFF059669)
                      : const Color(0xFFD92D20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ReportRangeSelector(
            range: _range,
            onPickRange: _pickRange,
            onThisMonth: () => setState(() => _range = reportMonthRange(DateTime.now())),
            onLastMonth: () => setState(() => _range = reportPreviousMonthRange(DateTime.now())),
            onLast30Days: () => setState(() => _range = reportLast30DaysRange(DateTime.now())),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ReportExportButton(
                  label: 'Download XLSX',
                  icon: Icons.table_chart_outlined,
                  color: const Color(0xFF059669),
                  isBusy: exporting,
                  onTap: _exportXlsx,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ReportExportButton(
                  label: 'Download PDF',
                  icon: Icons.picture_as_pdf_rounded,
                  color: const Color(0xFFF97316),
                  isBusy: exporting,
                  onTap: _exportPdf,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Statement',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF101828),
            ),
          ),
          const SizedBox(height: 10),
          ReportRowTile(
            icon: Icons.storefront_outlined,
            iconColor: const Color(0xFF9A3412),
            title: 'Sales Revenue',
            subtitle: 'Total sales in period',
            trailing: money(data.revenue),
          ),
          const SizedBox(height: 8),
          ReportRowTile(
            icon: Icons.inventory_2_outlined,
            iconColor: const Color(0xFFB45309),
            title: 'Cost of Goods Sold',
            subtitle: 'Purchase cost of sold items',
            trailing: money(data.cogs),
          ),
          const SizedBox(height: 8),
          ReportRowTile(
            icon: Icons.trending_up_rounded,
            iconColor: const Color(0xFF059669),
            title: 'Gross Profit',
            subtitle: 'Revenue minus cost of goods',
            trailing: money(data.grossProfit),
          ),
          const SizedBox(height: 8),
          ReportRowTile(
            icon: Icons.receipt_long_outlined,
            iconColor: const Color(0xFFF97316),
            title: 'Operating Expenses',
            subtitle: 'Expenses in period',
            trailing: money(data.expenses),
          ),
          const SizedBox(height: 8),
          ReportRowTile(
            icon: profitable
                ? Icons.emoji_events_outlined
                : Icons.trending_down_rounded,
            iconColor: profitable
                ? const Color(0xFF059669)
                : const Color(0xFFD92D20),
            title: 'Net Profit',
            subtitle: profitable ? 'Business is profitable' : 'Business is at a loss',
            trailing: money(data.netProfit),
            titleColor: profitable
                ? const Color(0xFF059669)
                : const Color(0xFFD92D20),
          ),
          ],
        ),
        ),
        ),
      ),
    );
  }
}