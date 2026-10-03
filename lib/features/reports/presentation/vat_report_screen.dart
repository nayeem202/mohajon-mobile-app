import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/sale.dart';
import '../../../core/services/pdf_doc.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';
import '../../customers/providers/customer_providers.dart';
import '../../settings/providers/shop_profile_providers.dart';
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
    final l10n = AppLocalizations.of(context);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
      initialDateRange: _range,
      helpText: l10n.t('selectVatRange'),
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

  ({List<Map<String, Object?>> rows, int vatSaleCount, double totalVat,
      double avgRate, ReportTableData table}) _compute() {
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
      // VAT is charged on the discount-adjusted taxable value, matching the
      // checkout calculation and preventing over-reporting when a discount
      // was applied.
      final taxable = (subtotal - sale.discount).clamp(0, double.infinity).toDouble();
      final vat = taxable * (sale.vatPercent / 100);
      rows.add(<String, Object?>{
        'date': sale.createdAt,
        'invoice': sale.invoiceNumber.isNotEmpty ? sale.invoiceNumber : sale.saleId,
        'customer': _customerLabel(customerById[sale.customerId], sale),
        'subtotal': taxable,
        'vatPercent': sale.vatPercent,
        'vat': vat,
      });
    }
    rows.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    final totalVat = rows.fold<double>(0, (sum, row) => sum + (row['vat'] as double));
    final vatableSubtotal =
        rows.fold<double>(0, (sum, row) => sum + (row['subtotal'] as double));
    final avgRate = vatableSubtotal == 0
        ? 0.0
        : totalVat / vatableSubtotal * 100;

    final table = ReportTableData(
      title: 'VAT Report',
      subtitle: reportRangeLabel(_range),
      summaries: [
        ReportSummary(
          label: 'Total VAT',
          value: money(totalVat),
          accent: 0xFFEA580C,
        ),
        ReportSummary(
          label: 'Vatable Sales',
          value: '${rows.length}',
          accent: 0xFF1E3A8A,
        ),
        ReportSummary(
          label: 'Avg VAT / Sale',
          value: rows.isEmpty ? '0' : money(totalVat / rows.length),
          accent: 0xFFD97706,
        ),
        ReportSummary(
          label: 'Avg Rate',
          value: rows.isEmpty
              ? '0%'
              : '${avgRate.toStringAsFixed(avgRate % 1 == 0 ? 0 : 1)}%',
          accent: 0xFF059669,
        ),
      ],
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
      avgRate: avgRate,
      table: table,
    );
  }

  String _customerLabel(Customer? customer, Sale sale) {
    final l10n = AppLocalizations.of(context);
    if (customer != null && customer.name.isNotEmpty) return customer.name;
    if (sale.customerId.isEmpty || sale.customerId.toLowerCase() == 'walk_in') {
      return l10n.t('walkIn');
    }
    return l10n.t('unknownCustomer');
  }

  Future<void> _exportXlsx() => runExport(
        isXlsx: true,
        task: () async {
          final data = _compute();
          await VatReportExcelService()
              .saveVatReport(table: data.table, range: _range);
        },
        message: AppLocalizations.of(context)
            .tP('exportedAsXlsx', {'report': AppLocalizations.of(context).t('reportVat')}),
      );

  Future<void> _exportPdf() => runExport(
        isXlsx: false,
        task: () async {
          final data = _compute();
          final company =
              DocCompany.fromShop(ref.read(shopProfileProvider).value);
          await VatReportPdfService()
              .saveVatReport(table: data.table, range: _range, company: company);
        },
        message: AppLocalizations.of(context)
            .tP('exportedAsPdf', {'report': AppLocalizations.of(context).t('reportVat')}),
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
            l10n.t('reportVat'),
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
                  label: l10n.t('totalVat'),
                  value: money(data.totalVat),
                  valueColor: const Color(0xFFF97316),
                  icon: Icons.calculate_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ReportSummaryCard(
                  label: l10n.t('vatableSales'),
                  value: '${data.vatSaleCount}',
                  valueColor: MohajonWarm.goldText,
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
                  label: l10n.t('avgVatPerSale'),
                  value: data.vatSaleCount == 0
                      ? '0'
                      : money(data.totalVat / data.vatSaleCount),
                  valueColor: const Color(0xFF9A3412),
                  icon: Icons.calculate_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ReportSummaryCard(
                  label: l10n.t('avgVatRate'),
                  subtitle: l10n.t('avgVatRateSub'),
                  value: data.vatSaleCount == 0
                      ? '0%'
                      : '${data.avgRate.toStringAsFixed(data.avgRate % 1 == 0 ? 0 : 1)}%',
                  valueColor: const Color(0xFF059669),
                  icon: Icons.percent_rounded,
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
                  l10n.t('vatCollected'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF101828),
                  ),
                ),
              ),
              Text(
                l10n.tP('xSalesCount', {'count': '${data.rows.length}'}),
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
              subtitle: l10n.tP('subtotalAtPct', {
                'customer': '${row['customer']}',
                'amount': money(row['subtotal'] as double),
                'pct': '${row['vatPercent']}',
              }),
              trailing: money(row['vat'] as double),
            ),
            const SizedBox(height: 8),
          ],
          if (data.rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  l10n.t('noVatInPeriod'),
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
