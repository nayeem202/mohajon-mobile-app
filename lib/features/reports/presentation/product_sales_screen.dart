import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/sale.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';
import '../../customers/providers/customer_providers.dart';
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
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
      initialDateRange: _range,
      helpText: 'Select sales range',
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

  ({List<Map<String, Object?>> rows, int productCount, double totalRevenue,
      double totalProfit, ReportTableData table}) _compute() {
    final sales = ref.watch(salesStreamProvider).value ?? const <Sale>[];
    final aggregates = <String, Map<String, Object?>>{};
    for (final sale in sales) {
      if (!_inRange(sale.createdAt)) continue;
      for (final item in sale.items) {
        final entry = aggregates.putIfAbsent(item.name, () {
          return <String, Object?>{'qty': 0.0, 'revenue': 0.0, 'profit': 0.0};
        });
        entry['qty'] = (entry['qty'] as double) + item.qty;
        entry['revenue'] = (entry['revenue'] as double) + item.lineTotal;
        entry['profit'] = (entry['profit'] as double) + item.profit;
      }
    }
    final rows = aggregates.entries
        .map((entry) => <String, Object?>{
              'product': entry.key,
              'qty': entry.value['qty'],
              'revenue': entry.value['revenue'],
              'profit': entry.value['profit'],
            })
        .toList()
      ..sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));

    final totalRevenue =
        rows.fold<double>(0, (sum, row) => sum + (row['revenue'] as double));
    final totalProfit =
        rows.fold<double>(0, (sum, row) => sum + (row['profit'] as double));

    final table = ReportTableData(
      title: 'Product-wise Sales',
      subtitle: reportRangeLabel(_range),
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
        task: () async {
          final data = _compute();
          await ProductSalesExcelService()
              .saveProductSales(table: data.table, range: _range);
        },
        message: 'Product-wise sales exported as XLSX',
      );

  Future<void> _exportPdf() => runExport(
        task: () async {
          final data = _compute();
          await ProductSalesPdfService()
              .saveProductSales(table: data.table, range: _range);
        },
        message: 'Product-wise sales exported as PDF',
      );

  @override
  Widget build(BuildContext context) {
    final data = _compute();

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F1),
      appBar: AppBar(
        title: const Text(
          'Product-wise Sales',
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
                  label: 'Products Sold',
                  value: '${data.productCount}',
                  valueColor: const Color(0xFF101828),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ReportSummaryCard(
                  label: 'Total Revenue',
                  value: money(data.totalRevenue),
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
                  label: 'Total Profit',
                  value: money(data.totalProfit),
                  valueColor: const Color(0xFFF97316),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ReportSummaryCard(
                  label: 'Top Seller',
                  value: data.rows.isEmpty ? '—' : '${data.rows.first['product']}',
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
                  'Best Sellers',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF101828),
                  ),
                ),
              ),
              Text(
                '${data.rows.length} products',
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
              subtitle:
                  '${_qty(data.rows[i]['qty'])} units  •  profit ${money(data.rows[i]['profit'] as double)}',
              trailing: money(data.rows[i]['revenue'] as double),
            ),
            const SizedBox(height: 8),
          ],
          if (data.rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No sales in this period',
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

  String _qty(Object? value) {
    final qty = value as double;
    return qty % 1 == 0 ? '${qty.toInt()}' : qty.toStringAsFixed(2);
  }
}
