import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/models/sale.dart';
import '../../../core/services/pdf_doc.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';
import '../../customers/providers/customer_providers.dart';
import '../../expenses/models/expense.dart';
import '../../expenses/providers/expense_providers.dart';
import '../../settings/providers/shop_profile_providers.dart';
import '../../pos/services/sale_return_service.dart';
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
    final l10n = AppLocalizations.of(context);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
      initialDateRange: _range,
      helpText: l10n.t('selectProfitLossRange'),
      saveText: l10n.t('applyLabel'),
    );
    if (picked == null) return;
    setState(() => _range = picked);
  }

  bool _inRange(DateTime value) {
    final end = _range.end;
    return !value.isBefore(_range.start) &&
        !value.isAfter(DateTime(end.year, end.month, end.day, 23, 59, 59));
  }

  ({
    double revenue,
    double cogs,
    double grossProfit,
    double expenses,
    double netProfit,
    ReportTableData table,
  })
  _compute() {
    final sales = ref.watch(salesStreamProvider).value ?? const <Sale>[];
    final allExpenses = ref.watch(expensesProvider).value ?? const <Expense>[];
    final returns = ref.watch(saleReturnsProvider).value ?? const [];
    final selectedSales = sales
        .where((sale) => _inRange(sale.createdAt))
        .toList();
    final selectedExpenses = allExpenses
        .where((expense) => _inRange(expense.date))
        .toList();
    final returnedQty = <String, double>{};
    for (final value in returns.where((item) => !item.isDeleted)) {
      for (final item in value.items) {
        returnedQty['${value.saleId}:${item.saleItemId}'] =
            (returnedQty['${value.saleId}:${item.saleItemId}'] ?? 0) + item.qty;
      }
    }

    final revenue = selectedSales.fold<double>(
      0,
      (sum, sale) => sum + sale.totalAmount,
    );
    final cogs = selectedSales.fold<double>(
      0,
      (sum, sale) =>
          sum +
          sale.items.fold<double>(0, (acc, item) {
            final qty =
                (item.qty -
                        (returnedQty['${sale.saleId}:${item.saleItemId}'] ?? 0))
                    .clamp(0, double.infinity);
            return acc + qty * item.purchasePrice;
          }),
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
      summaries: [
        ReportSummary(
          label: 'Revenue',
          value: money(revenue),
          accent: 0xFF1E3A8A,
        ),
        ReportSummary(
          label: 'Gross Profit',
          value: money(grossProfit),
          accent: 0xFF059669,
        ),
        ReportSummary(
          label: 'Expenses',
          value: money(expenses),
          accent: 0xFFEA580C,
        ),
        ReportSummary(
          label: 'Net Profit',
          value: money(netProfit),
          accent: netProfit >= 0 ? 0xFF059669 : 0xFFD92D20,
        ),
      ],
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
    isXlsx: true,
    task: () async {
      final data = _compute();
      await ProfitLossExcelService().saveProfitLoss(
        table: data.table,
        range: _range,
      );
    },
    message: AppLocalizations.of(context).tP('exportedAsXlsx', {
      'report': AppLocalizations.of(context).t('reportProfitLoss'),
    }),
  );

  Future<void> _exportPdf() => runExport(
    isXlsx: false,
    task: () async {
      final data = _compute();
      final company = await DocCompany.fromShopForExport(
        ref.read(shopProfileProvider).value,
      );
      await ProfitLossPdfService().saveProfitLoss(
        table: data.table,
        range: _range,
        company: company,
      );
    },
    message: AppLocalizations.of(context).tP('exportedAsPdf', {
      'report': AppLocalizations.of(context).t('reportProfitLoss'),
    }),
  );

  @override
  Widget build(BuildContext context) {
    final data = _compute();
    final profitable = data.netProfit >= 0;
    final l10n = AppLocalizations.of(context);

    return Theme(
      data: MohajonWarm.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            l10n.t('reportProfitLoss'),
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
          actions: const [NotificationBell(), SizedBox(width: 6), ShopAvatar()],
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: MohajonWarm.pageGradient),
          child: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                ReportBrandStrip(
                  title: l10n.t('reportProfitLoss'),
                  icon: Icons.trending_up_rounded,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ReportSummaryCard(
                        label: l10n.t('revenueLabel'),
                        value: money(data.revenue),
                        valueColor: MohajonWarm.goldText,
                        icon: Icons.attach_money_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ReportSummaryCard(
                        label: l10n.t('grossProfit'),
                        value: money(data.grossProfit),
                        valueColor: const Color(0xFF059669),
                        icon: Icons.trending_up_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ReportSummaryCard(
                        label: l10n.t('operatingExpenses'),
                        value: money(data.expenses),
                        valueColor: const Color(0xFFF97316),
                        icon: Icons.receipt_long_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ReportSummaryCard(
                        label: l10n.t('netProfit'),
                        value: money(data.netProfit),
                        valueColor: profitable
                            ? const Color(0xFF059669)
                            : const Color(0xFFD92D20),
                        icon: Icons.calculate_rounded,
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
                        onTap: _exportXlsx,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ReportExportButton(
                        label: l10n.t('downloadPdf'),
                        icon: Icons.picture_as_pdf_rounded,
                        color: const Color(0xFFF97316),
                        isBusy: exportingPdf,
                        onTap: _exportPdf,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  l10n.t('statement'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF101828),
                  ),
                ),
                const SizedBox(height: 10),
                ReportRowTile(
                  icon: Icons.storefront_outlined,
                  iconColor: const Color(0xFF9A3412),
                  title: l10n.t('salesRevenue'),
                  subtitle: l10n.t('salesRevenueSub'),
                  trailing: money(data.revenue),
                ),
                const SizedBox(height: 8),
                ReportRowTile(
                  icon: Icons.inventory_2_outlined,
                  iconColor: const Color(0xFFB45309),
                  title: l10n.t('cogs'),
                  subtitle: l10n.t('cogsSub'),
                  trailing: money(data.cogs),
                ),
                const SizedBox(height: 8),
                ReportRowTile(
                  icon: Icons.trending_up_rounded,
                  iconColor: const Color(0xFF059669),
                  title: l10n.t('grossProfit'),
                  subtitle: l10n.t('grossProfitSub'),
                  trailing: money(data.grossProfit),
                ),
                const SizedBox(height: 8),
                ReportRowTile(
                  icon: Icons.receipt_long_outlined,
                  iconColor: const Color(0xFFF97316),
                  title: l10n.t('operatingExpenses'),
                  subtitle: l10n.t('operatingExpensesSub'),
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
                  title: l10n.t('netProfit'),
                  subtitle: profitable
                      ? l10n.t('netProfitSub')
                      : l10n.t('netLossSub'),
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
