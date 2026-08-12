import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/sale.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';
import '../../customers/providers/customer_providers.dart';
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

class _DailyTransactionsScreenState extends ConsumerState<DailyTransactionsScreen>
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
      helpText: 'Select transactions range',
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

  ({List<DailySales> days, Map<DateTime, double> receivedByDay,
      int transactionCount, double salesAmount, double received,
      ReportTableData table}) _compute() {
    final sales = ref.watch(salesStreamProvider).value ?? const <Sale>[];
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
      final amount = daySales.fold<double>(0, (sum, sale) => sum + sale.totalAmount);
      final received = daySales.fold<double>(0, (sum, sale) => sum + sale.paidAmount);
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

    final transactionCount = days.fold<int>(
      0,
      (sum, day) => sum + day.transactionCount,
    );
    final salesAmount = days.fold<double>(0, (sum, day) => sum + day.amount);
    final received = receivedByDay.values.fold<double>(0, (sum, value) => sum + value);

    final table = ReportTableData(
      title: 'Daily Transactions',
      subtitle: reportRangeLabel(_range),
      columns: const [
        ReportTableColumn(key: 'date', header: 'Date', weight: 1.5),
        ReportTableColumn(key: 'sales', header: 'Sales', rightAlign: true),
        ReportTableColumn(
          key: 'amount',
          header: 'Sales Amount',
          rightAlign: true,
        ),
        ReportTableColumn(key: 'received', header: 'Received', rightAlign: true),
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
        task: () async {
          final data = _compute();
          await DailyTransactionsExcelService()
              .saveDailyTransactions(table: data.table, range: _range);
        },
        message: 'Daily transactions exported as XLSX',
      );

  Future<void> _exportPdf() => runExport(
        task: () async {
          final data = _compute();
          await DailyTransactionsPdfService()
              .saveDailyTransactions(table: data.table, range: _range);
        },
        message: 'Daily transactions exported as PDF',
      );

  @override
  Widget build(BuildContext context) {
    final data = _compute();

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F1),
      appBar: AppBar(
        title: const Text(
          'Daily Transactions',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        actions: [
          const NotificationBell(),
          const SizedBox(width: 4),
          const ShopAvatar(
            radius: 16,
            backgroundColor: Color(0xFFF97316),
            textColor: Colors.white,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: ReportSummaryCard(
                  label: 'Transactions',
                  value: '${data.transactionCount}',
                  valueColor: const Color(0xFF101828),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ReportSummaryCard(
                  label: 'Sales',
                  value: money(data.salesAmount),
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
                  label: 'Received',
                  value: money(data.received),
                  valueColor: const Color(0xFFF97316),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ReportSummaryCard(
                  label: 'Active Days',
                  value: '${data.days.length}',
                  valueColor: const Color(0xFF9A3412),
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
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Daily Breakdown',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF101828),
                  ),
                ),
              ),
              Text(
                '${data.days.length} days',
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
              subtitle:
                  '${day.transactionCount} sales  •  received ${money(data.receivedByDay[day.date] ?? 0)}',
              trailing: money(day.amount),
            ),
            const SizedBox(height: 8),
          ],
          if (data.days.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No transactions in this period',
                  style: TextStyle(
                    color: Color(0xFF98A2B3),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}