import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/models/sale.dart';
import '../../../core/models/payment.dart';
import '../../../core/services/pdf_doc.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';
import '../../customers/providers/customer_providers.dart';
import '../../settings/providers/shop_profile_providers.dart';
import '../../pos/services/sale_return_service.dart';
import '../models/daily_sales.dart';
import '../models/table_report.dart';
import '../services/daily_transactions_excel_service.dart';
import '../services/daily_transactions_pdf_service.dart';
import 'report_shared_widgets.dart';

class DailyTransactionsScreen extends ConsumerStatefulWidget {
  const DailyTransactionsScreen({super.key});

  @override
  ConsumerState<DailyTransactionsScreen> createState() =>
      _DailyTransactionsScreenState();
}

class _DailyTransactionsScreenState
    extends ConsumerState<DailyTransactionsScreen>
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
      helpText: l10n.t('selectTransactionsRange'),
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
    List<DailySales> days,
    Map<DateTime, double> receivedByDay,
    int transactionCount,
    double salesAmount,
    double received,
    ReportTableData table,
  })
  _compute() {
    final sales = ref.watch(salesStreamProvider).value ?? const <Sale>[];
    final payments =
        ref.watch(paymentsStreamProvider).value ?? const <Payment>[];
    final returns = ref.watch(saleReturnsProvider).value ?? const [];
    final byDay = <DateTime, List<Sale>>{};
    for (final sale in sales) {
      if (!_inRange(sale.createdAt)) continue;
      final day = DateTime(
        sale.createdAt.year,
        sale.createdAt.month,
        sale.createdAt.day,
      );
      byDay.putIfAbsent(day, () => []).add(sale);
    }

    final dayKeys = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    final days = <DailySales>[];
    final receivedByDay = <DateTime, double>{};
    for (final day in dayKeys) {
      final daySales = byDay[day]!;
      final amount = daySales.fold<double>(
        0,
        (sum, sale) => sum + sale.totalAmount,
      );
      final received = daySales.fold<double>(
        0,
        (sum, sale) => sum + sale.paidAmount,
      );
      receivedByDay[day] = received;
      days.add(
        DailySales(
          date: day,
          label: DateFormat('dd MMM').format(day),
          amount: amount,
          transactionCount: daySales.length,
          maxAmount: amount,
        ),
      );
    }

    for (final payment in payments) {
      if (!_inRange(payment.createdAt)) continue;
      final day = DateTime(
        payment.createdAt.year,
        payment.createdAt.month,
        payment.createdAt.day,
      );
      // Checkout payments are already included in Sale.paidAmount.
      if (payment.saleId == null) {
        receivedByDay[day] = (receivedByDay[day] ?? 0) + payment.amount;
      }
    }
    for (final value in returns) {
      if (!_inRange(value.createdAt) || value.isDeleted) continue;
      final day = DateTime(
        value.createdAt.year,
        value.createdAt.month,
        value.createdAt.day,
      );
      receivedByDay[day] = (receivedByDay[day] ?? 0) - value.refundAmount;
    }

    final transactionCount = days.fold<int>(
      0,
      (sum, day) => sum + day.transactionCount,
    );
    final salesAmount = days.fold<double>(0, (sum, day) => sum + day.amount);
    final received = receivedByDay.values.fold<double>(
      0,
      (sum, value) => sum + value,
    );

    final table = ReportTableData(
      title: 'Daily Transactions',
      subtitle: reportRangeLabel(_range),
      summaries: [
        ReportSummary(
          label: 'Transactions',
          value: '$transactionCount',
          accent: 0xFF1E3A8A,
        ),
        ReportSummary(
          label: 'Sales Amount',
          value: money(salesAmount),
          accent: 0xFFEA580C,
        ),
        ReportSummary(
          label: 'Received',
          value: money(received),
          accent: 0xFF059669,
        ),
        ReportSummary(
          label: 'Active Days',
          value: '${days.length}',
          accent: 0xFFD97706,
        ),
      ],
      columns: const [
        ReportTableColumn(key: 'date', header: 'Date', weight: 1.5),
        ReportTableColumn(key: 'sales', header: 'Sales', rightAlign: true),
        ReportTableColumn(
          key: 'amount',
          header: 'Sales Amount',
          rightAlign: true,
        ),
        ReportTableColumn(
          key: 'received',
          header: 'Received',
          rightAlign: true,
        ),
      ],
      rows: [
        for (final day in days)
          {
            'date': day.date,
            'sales': day.transactionCount,
            'amount': day.amount,
            'received': receivedByDay[day.date] ?? 0,
          },
      ],
    );

    return (
      days: days,
      receivedByDay: receivedByDay,
      transactionCount: transactionCount,
      salesAmount: salesAmount,
      received: received,
      table: table,
    );
  }

  Future<void> _exportXlsx() => runExport(
    isXlsx: true,
    task: () async {
      final data = _compute();
      await DailyTransactionsExcelService().saveDailyTransactions(
        table: data.table,
        range: _range,
      );
    },
    message: AppLocalizations.of(context).tP('exportedAsXlsx', {
      'report': AppLocalizations.of(context).t('reportDailyTransactions'),
    }),
  );

  Future<void> _exportPdf() => runExport(
    isXlsx: false,
    task: () async {
      final data = _compute();
      final company = await DocCompany.fromShopForExport(
        ref.read(shopProfileProvider).value,
      );
      await DailyTransactionsPdfService().saveDailyTransactions(
        table: data.table,
        range: _range,
        company: company,
      );
    },
    message: AppLocalizations.of(context).tP('exportedAsPdf', {
      'report': AppLocalizations.of(context).t('reportDailyTransactions'),
    }),
  );

  @override
  Widget build(BuildContext context) {
    final data = _compute();
    final l10n = AppLocalizations.of(context);

    return Theme(
      data: MohajonWarm.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            l10n.t('reportDailyTransactions'),
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
                  title: l10n.t('reportDailyTransactions'),
                  icon: Icons.receipt_long_rounded,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ReportSummaryCard(
                        label: l10n.t('transactions'),
                        value: '${data.transactionCount}',
                        valueColor: MohajonWarm.goldText,
                        icon: Icons.receipt_long_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ReportSummaryCard(
                        label: l10n.t('sales'),
                        value: money(data.salesAmount),
                        valueColor: const Color(0xFF059669),
                        icon: Icons.attach_money_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ReportSummaryCard(
                        label: l10n.t('receivedLabel'),
                        value: money(data.received),
                        valueColor: const Color(0xFFF97316),
                        icon: Icons.call_received_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ReportSummaryCard(
                        label: l10n.t('activeDays'),
                        value: '${data.days.length}',
                        valueColor: const Color(0xFF9A3412),
                        icon: Icons.bolt_rounded,
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.t('dailyBreakdown'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF101828),
                        ),
                      ),
                    ),
                    Text(
                      l10n.tP('xDays', {'count': '${data.days.length}'}),
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final day in data.days) ...[
                  ReportRowTile(
                    icon: Icons.calendar_today_outlined,
                    iconColor: const Color(0xFFF97316),
                    title: DateFormat('EEEE, dd MMM yyyy').format(day.date),
                    subtitle: l10n.tP('salesReceived', {
                      'count': '${day.transactionCount}',
                      'amount': money(data.receivedByDay[day.date] ?? 0),
                    }),
                    trailing: money(day.amount),
                  ),
                  const SizedBox(height: 8),
                ],
                if (data.days.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        l10n.t('noTransactionsInPeriod'),
                        style: const TextStyle(
                          color: Color(0xFF98A2B3),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
