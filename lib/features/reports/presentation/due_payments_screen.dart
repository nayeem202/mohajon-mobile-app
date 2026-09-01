import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/customer.dart';
import '../../../core/models/sale.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/customer_ledger_entry.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';
import '../../customers/providers/customer_providers.dart';
import '../models/table_report.dart';
import '../services/due_payments_excel_service.dart';
import '../services/due_payments_pdf_service.dart';
import 'report_shared_widgets.dart';

class DuePaymentsScreen extends ConsumerStatefulWidget {
  const DuePaymentsScreen({super.key});

  @override
  ConsumerState<DuePaymentsScreen> createState() => _DuePaymentsScreenState();
}

class _DuePaymentsScreenState extends ConsumerState<DuePaymentsScreen>
    with ReportExportMixin {
  ({
    List<Map<String, Object?>> rows,
    double totalDue,
    int customerCount,
    ReportTableData table,
  })
  _compute() {
    final sales = ref.watch(salesStreamProvider).value ?? const <Sale>[];
    final payments = ref.watch(paymentsStreamProvider).value ?? const <Payment>[];
    final ledgerEntries = ref.watch(customerLedgerEntriesStreamProvider).value ??
        const <CustomerLedgerEntry>[];
    final customers = ref.watch(customersProvider).value ?? const <Customer>[];
    final byCustomer = <String, Map<String, Object?>>{};
    for (final sale in sales) {
      final entry = byCustomer.putIfAbsent(sale.customerId, () {
        return <String, Object?>{'due': 0.0, 'count': 0};
      });
      entry['due'] = (entry['due'] as double) + sale.dueAmount;
      if (sale.dueAmount > 0) entry['count'] = (entry['count'] as int) + 1;
    }
    for (final payment in payments.where((p) => p.saleId == null)) {
      final entry = byCustomer.putIfAbsent(payment.customerId, () {
        return <String, Object?>{'due': 0.0, 'count': 0};
      });
      entry['due'] = (entry['due'] as double) - payment.amount;
    }
    for (final adjustment in ledgerEntries) {
      final entry = byCustomer.putIfAbsent(adjustment.customerId, () {
        return <String, Object?>{'due': 0.0, 'count': 0};
      });
      entry['due'] = (entry['due'] as double) + adjustment.signedAmount;
    }

    final customerByName = <String, Customer>{
      for (final customer in customers) customer.customerId: customer,
    };
    final rows =
        byCustomer.entries
            .where((entry) => (entry.value['due'] as double) > 0)
            .map(
              (entry) => <String, Object?>{
                'customer': entry.key,
                'name': _customerLabel(customerByName[entry.key]),
                'phone': customerByName[entry.key]?.phone ?? '',
                'due': entry.value['due'],
                'count': entry.value['count'],
              },
            )
            .toList()
          ..sort((a, b) => (b['due'] as double).compareTo(a['due'] as double));

    final totalDue = rows.fold<double>(
      0,
      (sum, row) => sum + (row['due'] as double),
    );

    final table = ReportTableData(
      title: 'Due Payments',
      subtitle: 'All time',
      columns: const [
        ReportTableColumn(key: 'name', header: 'Customer', weight: 2.5),
        ReportTableColumn(key: 'phone', header: 'Phone', weight: 1.5),
        ReportTableColumn(key: 'due', header: 'Due Amount', rightAlign: true),
        ReportTableColumn(key: 'count', header: 'Open Sales', rightAlign: true),
      ],
      rows: rows,
    );

    return (
      rows: rows,
      totalDue: totalDue,
      customerCount: rows.length,
      table: table,
    );
  }

  String _customerLabel(Customer? customer) {
    if (customer == null || customer.name.isEmpty) return 'Unknown customer';
    return customer.name;
  }

  Future<void> _exportXlsx() => runExport(
    task: () async {
      final data = _compute();
      await DuePaymentsExcelService().saveDuePayments(
        table: data.table,
        range: _allTimeRange(),
      );
    },
    message: 'Due payments exported as XLSX',
  );

  Future<void> _exportPdf() => runExport(
    task: () async {
      final data = _compute();
      await DuePaymentsPdfService().saveDuePayments(
        table: data.table,
        range: _allTimeRange(),
      );
    },
    message: 'Due payments exported as PDF',
  );

  DateTimeRange _allTimeRange() {
    final now = DateTime.now();
    return DateTimeRange(start: DateTime(2000), end: now);
  }

  @override
  Widget build(BuildContext context) {
    final data = _compute();

    return Theme(
      data: MohajonWarm.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Due Payments',
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
                  label: 'Total Due',
                  value: money(data.totalDue),
                  valueColor: const Color(0xFFD92D20),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ReportSummaryCard(
                  label: 'Customers with Due',
                  value: '${data.customerCount}',
                  valueColor: MohajonWarm.goldText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFD92D20), Color(0xFFF97316)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.white),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Customers owe this amount against open sale invoices. Collect dues to keep the books clean.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
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
                  'Outstanding Customers',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF101828),
                  ),
                ),
              ),
              Text(
                '${data.rows.length} customers',
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
              icon: Icons.person_outline,
              iconColor: const Color(0xFFD92D20),
              title: '${row['name']}',
              subtitle: (row['phone'] as String).isNotEmpty
                  ? '${row['phone']}  •  ${row['count']} open sale(s)'
                  : '${row['count']} open sale(s)',
              trailing: money(row['due'] as double),
            ),
            const SizedBox(height: 8),
          ],
          if (data.rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No dues recorded. All clear!',
                  style: TextStyle(
                    color: Color(0xFF059669),
                    fontWeight: FontWeight.w700,
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
