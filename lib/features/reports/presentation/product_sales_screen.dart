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
import '../../settings/providers/shop_profile_providers.dart';
import '../../pos/services/sale_return_service.dart';
import '../models/table_report.dart';
import '../services/product_sales_excel_service.dart';
import '../services/product_sales_pdf_service.dart';
import 'report_shared_widgets.dart';

class ProductSalesScreen extends ConsumerStatefulWidget {
  const ProductSalesScreen({super.key});

  @override
  ConsumerState<ProductSalesScreen> createState() => _ProductSalesScreenState();
}

class _ProductSalesScreenState extends ConsumerState<ProductSalesScreen>
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
      helpText: l10n.t('selectSalesRange'),
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
    List<Map<String, Object?>> rows,
    int productCount,
    double totalRevenue,
    double totalProfit,
    ReportTableData table,
  })
  _compute() {
    final sales = ref.watch(salesStreamProvider).value ?? const <Sale>[];
    final returns = ref.watch(saleReturnsProvider).value ?? const [];
    final returnedQty = <String, double>{};
    for (final value in returns.where((item) => !item.isDeleted)) {
      for (final item in value.items) {
        returnedQty['${value.saleId}:${item.saleItemId}'] =
            (returnedQty['${value.saleId}:${item.saleItemId}'] ?? 0) + item.qty;
      }
    }
    final aggregates = <String, Map<String, Object?>>{};
    for (final sale in sales) {
      if (!_inRange(sale.createdAt)) continue;
      for (final item in sale.items) {
        final qty =
            (item.qty - (returnedQty['${sale.saleId}:${item.saleItemId}'] ?? 0))
                .clamp(0, double.infinity);
        final entry = aggregates.putIfAbsent(item.name, () {
          return <String, Object?>{'qty': 0.0, 'revenue': 0.0, 'profit': 0.0};
        });
        entry['qty'] = (entry['qty'] as double) + qty;
        entry['revenue'] = (entry['revenue'] as double) + qty * item.unitPrice;
        entry['profit'] =
            (entry['profit'] as double) +
            qty * (item.unitPrice - item.purchasePrice);
      }
    }
    final rows =
        aggregates.entries
            .map(
              (entry) => <String, Object?>{
                'product': entry.key,
                'qty': entry.value['qty'],
                'revenue': entry.value['revenue'],
                'profit': entry.value['profit'],
              },
            )
            .toList()
          ..sort(
            (a, b) =>
                (b['revenue'] as double).compareTo(a['revenue'] as double),
          );

    final totalRevenue = rows.fold<double>(
      0,
      (sum, row) => sum + (row['revenue'] as double),
    );
    final totalProfit = rows.fold<double>(
      0,
      (sum, row) => sum + (row['profit'] as double),
    );
    final productCount = rows.length;

    final table = ReportTableData(
      title: 'Product-wise Sales',
      subtitle: reportRangeLabel(_range),
      summaries: [
        ReportSummary(
          label: 'Products Sold',
          value: '$productCount',
          accent: 0xFF1E3A8A,
        ),
        ReportSummary(
          label: 'Total Revenue',
          value: money(totalRevenue),
          accent: 0xFF059669,
        ),
        ReportSummary(
          label: 'Total Profit',
          value: money(totalProfit),
          accent: 0xFFEA580C,
        ),
        ReportSummary(
          label: 'Top Selling Product',
          value: rows.isEmpty ? '—' : '${rows.first['product']}',
          accent: 0xFFD97706,
        ),
      ],
      columns: const [
        ReportTableColumn(key: 'product', header: 'Product', weight: 3),
        ReportTableColumn(key: 'qty', header: 'Qty', rightAlign: true),
        ReportTableColumn(key: 'revenue', header: 'Revenue', rightAlign: true),
        ReportTableColumn(key: 'profit', header: 'Profit', rightAlign: true),
      ],
      rows: rows,
    );

    return (
      rows: rows,
      productCount: rows.length,
      totalRevenue: totalRevenue,
      totalProfit: totalProfit,
      table: table,
    );
  }

  Future<void> _exportXlsx() => runExport(
    isXlsx: true,
    task: () async {
      final data = _compute();
      await ProductSalesExcelService().saveProductSales(
        table: data.table,
        range: _range,
      );
    },
    message: AppLocalizations.of(context).tP('exportedAsXlsx', {
      'report': AppLocalizations.of(context).t('reportProductSales'),
    }),
  );

  Future<void> _exportPdf() => runExport(
    isXlsx: false,
    task: () async {
      final data = _compute();
      final company = DocCompany.fromShop(ref.read(shopProfileProvider).value);
      await ProductSalesPdfService().saveProductSales(
        table: data.table,
        range: _range,
        company: company,
      );
    },
    message: AppLocalizations.of(context).tP('exportedAsPdf', {
      'report': AppLocalizations.of(context).t('reportProductSales'),
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
            l10n.t('reportProductSales'),
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
                Row(
                  children: [
                    Expanded(
                      child: ReportSummaryCard(
                        label: l10n.t('productsSold'),
                        value: '${data.productCount}',
                        valueColor: MohajonWarm.goldText,
                        icon: Icons.shopping_bag_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ReportSummaryCard(
                        label: l10n.t('totalRevenue'),
                        value: money(data.totalRevenue),
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
                        label: l10n.t('totalProfit'),
                        value: money(data.totalProfit),
                        valueColor: const Color(0xFFF97316),
                        icon: Icons.trending_up_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ReportSummaryCard(
                        label: l10n.t('topSeller'),
                        value: data.rows.isEmpty
                            ? '—'
                            : '${data.rows.first['product']}',
                        valueColor: const Color(0xFF9A3412),
                        icon: Icons.emoji_events_outlined,
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
                        l10n.t('bestSellers'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF101828),
                        ),
                      ),
                    ),
                    Text(
                      l10n.tP('xProducts', {'count': '${data.rows.length}'}),
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < data.rows.length; i++) ...[
                  ReportRowTile(
                    icon: Icons.shopping_bag_outlined,
                    iconColor: const Color(0xFFF97316),
                    title: '${data.rows[i]['product']}',
                    subtitle: l10n.tP('xUnitsProfit', {
                      'qty': _qty(data.rows[i]['qty']),
                      'profit': money(data.rows[i]['profit'] as double),
                    }),
                    trailing: money(data.rows[i]['revenue'] as double),
                  ),
                  const SizedBox(height: 8),
                ],
                if (data.rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        l10n.t('noSalesInPeriod'),
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

  String _qty(Object? value) {
    final qty = value as double;
    return qty % 1 == 0 ? '${qty.toInt()}' : qty.toStringAsFixed(2);
  }
}
