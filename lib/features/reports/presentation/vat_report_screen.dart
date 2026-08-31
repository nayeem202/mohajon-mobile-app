import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/customer.dart';
import '../../../core/models/sale.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';
import '../../customers/providers/customer_providers.dart';
import '../models/table_report.dart';
import '../services/vat_report_excel_service.dart';
import '../services/vat_report_pdf_service.dart';
import 'report_shared_widgets.dart';

class VatReportScreen extends ConsumerStatefulWidget {
  const VatReportScreen({super.key});

  @override
  ConsumerState<VatReportScreen> createState() => _VatReportScreenState();
}

class _VatReportScreenState extends ConsumerState<VatReportScreen>
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
      helpText: 'Select VAT range',
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

  ({List<Map<String, Object?>> rows, int vatSaleCount, double totalVat,
      ReportTableData table}) _compute() {
    final sales = ref.watch(salesStreamProvider).value ?? const <Sale>[];
    final customers = ref.watch(customersProvider).value ?? const <Customer>[];
    final customerById = <String, Customer>{
      for (final customer in customers) customer.customerId: customer,
    };

    final rows = <Map<String, Object?>>[];
    for (final sale in sales) {
      if (sale.vatPercent <= 0 || !_inRange(sale.createdAt)) continue;
      final subtotal =
          sale.items.fold<double>(0, (sum, item) => sum + item.lineTotal);
      final vat = subtotal * (sale.vatPercent / 100);
      rows.add(<String, Object?>{
        'date': sale.createdAt,
        'invoice': sale.saleId,
        'customer': _customerLabel(customerById[sale.customerId], sale),
        'subtotal': subtotal,
        'vatPercent': sale.vatPercent,
        'vat': vat,
      });
    }
    rows.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    final totalVat = rows.fold<double>(0, (sum, row) => sum + (row['vat'] as double));

    final table = ReportTableData(
      title: 'VAT Report',
      subtitle: reportRangeLabel(_range),
      columns: const [
        ReportTableColumn(key: 'date', header: 'Date', weight: 1.4),
        ReportTableColumn(key: 'invoice', header: 'Invoice', weight: 1.4),
        ReportTableColumn(key: 'customer', header: 'Customer', weight: 1.8),
        ReportTableColumn(
          key: 'subtotal',
          header: 'Subtotal',
          rightAlign: true,
        ),
        ReportTableColumn(key: 'vatPercent', header: 'VAT %', rightAlign: true),
        ReportTableColumn(key: 'vat', header: 'VAT Amount', rightAlign: true),
      ],
      rows: [
        ...rows,
        {
          'date': 'TOTAL',
          'invoice': '',
          'customer': '',
          'subtotal': '',
          'vatPercent': '',
          'vat': totalVat,
        },
      ],
    );

    return (
      rows: rows,
      vatSaleCount: rows.length,
      totalVat: totalVat,
      table: table,
    );
  }

  String _customerLabel(Customer? customer, Sale sale) {
    if (customer != null && customer.name.isNotEmpty) return customer.name;
    if (sale.customerId.isEmpty || sale.customerId.toLowerCase() == 'walk_in') {
      return 'Walk-in';
    }
    return 'Unknown customer';
  }

  Future<void> _exportXlsx() => runExport(
        task: () async {
          final data = _compute();
          await VatReportExcelService()
              .saveVatReport(table: data.table, range: _range);
        },
        message: 'VAT report exported as XLSX',
      );

  Future<void> _exportPdf() => runExport(
        task: () async {
          final data = _compute();
          await VatReportPdfService()
              .saveVatReport(table: data.table, range: _range);
        },
        message: 'VAT report exported as PDF',
      );

  @override
  Widget build(BuildContext context) {
    final data = _compute();

    return Theme(
      data: MohajonWarm.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'VAT Report',
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
                  label: 'Total VAT',
                  value: money(data.totalVat),
                  valueColor: const Color(0xFFF97316),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ReportSummaryCard(
                  label: 'VATable Sales',
                  value: '${data.vatSaleCount}',
                  valueColor: const Color(0xFF101828),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ReportSummaryCard(
                  label: 'Average VAT / Sale',
                  value: data.vatSaleCount == 0
                      ? '0'
                      : money(data.totalVat / data.vatSaleCount),
                  valueColor: const Color(0xFF9A3412),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ReportSummaryCard(
                  label: 'Rate',
                  value: '5%',
                  valueColor: const Color(0xFF059669),
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
                  'VAT Collected',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF101828),
                  ),
                ),
              ),
              Text(
                '${data.rows.length} sales',
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
              icon: Icons.receipt_long_outlined,
              iconColor: const Color(0xFFF97316),
              title:
                  '${DateFormat('dd MMM yyyy').format(row['date'] as DateTime)}  •  #${(row['invoice'] as String).length > 8 ? (row['invoice'] as String).substring(0, 8) : row['invoice']}',
              subtitle:
                  '${row['customer']}  •  subtotal ${money(row['subtotal'] as double)} at ${row['vatPercent']}%',
              trailing: money(row['vat'] as double),
            ),
            const SizedBox(height: 8),
          ],
          if (data.rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No VAT charged in this period',
                  style: TextStyle(
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