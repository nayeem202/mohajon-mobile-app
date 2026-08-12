import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/payment.dart';
import '../../../core/models/sale.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';
import '../../customers/providers/customer_providers.dart';
import '../../payments/providers/payment_providers.dart';
import '../models/table_report.dart';
import '../services/payment_methods_excel_service.dart';
import '../services/payment_methods_pdf_service.dart';
import 'report_shared_widgets.dart';

class PaymentMethodsScreen extends ConsumerStatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  ConsumerState<PaymentMethodsScreen> createState() =>
      _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends ConsumerState<PaymentMethodsScreen>
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
      helpText: 'Select payments range',
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

  ({List<Map<String, Object?>> rows, int paymentCount, double received,
      ReportTableData table}) _compute() {
    final payments = ref.watch(paymentsProvider).value ?? const <Payment>[];
    final sales = ref.watch(salesStreamProvider).value ?? const <Sale>[];

    final byMethod = <String, Map<String, Object?>>{};
    for (final payment in payments) {
      if (!_inRange(payment.createdAt)) continue;
      final key = payment.paymentMethod.name;
      final entry = byMethod.putIfAbsent(key, () {
        return <String, Object?>{'count': 0, 'amount': 0.0};
      });
      entry['count'] = (entry['count'] as int) + 1;
      entry['amount'] = (entry['amount'] as double) + payment.amount;
    }

    var walkInCount = 0;
    var walkInAmount = 0.0;
    for (final sale in sales) {
      if (!_inRange(sale.createdAt)) continue;
      final hasCustomer =
          sale.customerId.isNotEmpty && sale.customerId.toLowerCase() != 'walk_in';
      if (!hasCustomer && sale.paidAmount > 0) {
        walkInCount++;
        walkInAmount += sale.paidAmount;
      }
    }
    if (walkInCount > 0) {
      byMethod['cash_walk_in'] = {
        'count': walkInCount,
        'amount': walkInAmount,
        'walkIn': true,
      };
    }

    final rows = byMethod.entries
        .map((entry) => <String, Object?>{
              'method': entry.key,
              'count': entry.value['count'],
              'amount': entry.value['amount'],
              'walkIn': entry.value['walkIn'] ?? false,
            })
        .toList()
      ..sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));

    final paymentCount = rows.fold<int>(
      0,
      (sum, row) => sum + (row['count'] as int),
    );
    final received = rows.fold<double>(
      0,
      (sum, row) => sum + (row['amount'] as double),
    );

    final table = ReportTableData(
      title: 'Payment Methods',
      subtitle: reportRangeLabel(_range),
      columns: const [
        ReportTableColumn(key: 'method', header: 'Method', weight: 2.5),
        ReportTableColumn(key: 'count', header: 'Payments', rightAlign: true),
        ReportTableColumn(key: 'amount', header: 'Amount', rightAlign: true),
      ],
      rows: [
        ...rows,
        {'method': 'TOTAL', 'count': paymentCount, 'amount': received},
      ],
    );

    return (
      rows: rows,
      paymentCount: paymentCount,
      received: received,
      table: table,
    );
  }

  Future<void> _exportXlsx() => runExport(
        task: () async {
          final data = _compute();
          await PaymentMethodsExcelService()
              .savePaymentMethods(table: data.table, range: _range);
        },
        message: 'Payment methods exported as XLSX',
      );

  Future<void> _exportPdf() => runExport(
        task: () async {
          final data = _compute();
          await PaymentMethodsPdfService()
              .savePaymentMethods(table: data.table, range: _range);
        },
        message: 'Payment methods exported as PDF',
      );

  IconData _methodIcon(String key) {
    switch (key) {
      case 'cash':
        return Icons.payments_outlined;
      case 'cash_walk_in':
        return Icons.storefront_outlined;
      case 'bkash':
      case 'nagad':
        return Icons.smartphone_outlined;
      case 'credit':
        return Icons.credit_card_outlined;
      case 'bank':
        return Icons.account_balance_outlined;
      default:
        return Icons.more_horiz;
    }
  }

  Color _methodColor(String key) {
    switch (key) {
      case 'cash':
        return const Color(0xFF059669);
      case 'cash_walk_in':
        return const Color(0xFF9A3412);
      case 'bkash':
      case 'nagad':
        return const Color(0xFFD97706);
      case 'credit':
        return const Color(0xFF0F766E);
      case 'bank':
        return const Color(0xFFB45309);
      default:
        return const Color(0xFF667085);
    }
  }

  String _methodLabel(String key) {
    if (key == 'cash_walk_in') return 'Cash (Walk-in)';
    return PaymentMethodX.parse(key).displayName;
  }

  @override
  Widget build(BuildContext context) {
    final data = _compute();

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F1),
      appBar: AppBar(
        title: const Text(
          'Payment Methods',
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
                  label: 'Payments',
                  value: '${data.paymentCount}',
                  valueColor: const Color(0xFF101828),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ReportSummaryCard(
                  label: 'Received',
                  value: money(data.received),
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
                  label: 'Methods Used',
                  value: '${data.rows.length}',
                  valueColor: const Color(0xFFF97316),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ReportSummaryCard(
                  label: 'Top Method',
                  value: data.rows.isEmpty ? '—' : _methodLabel('${data.rows.first['method']}'),
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
                  'Collections by Method',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF101828),
                  ),
                ),
              ),
              Text(
                'Total ${money(data.received)}',
                style: const TextStyle(
                  color: Color(0xFF667085),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final row in data.rows) ...[
            ReportRowTile(
              icon: _methodIcon('${row['method']}'),
              iconColor: _methodColor('${row['method']}'),
              title: _methodLabel('${row['method']}'),
              subtitle: '${row['count']} payments',
              trailing: money(row['amount'] as double),
            ),
            const SizedBox(height: 8),
          ],
          if (data.rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No payments in this period',
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