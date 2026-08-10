import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/sale.dart';
import '../../../core/utils/money.dart';
import '../../customers/providers/customer_providers.dart';
import '../models/daily_sales.dart';
import '../services/sales_summary_excel_service.dart';
import '../services/sales_summary_pdf_service.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';

class SalesSummaryScreen extends ConsumerStatefulWidget {
  const SalesSummaryScreen({super.key});

  @override
  ConsumerState<SalesSummaryScreen> createState() => _SalesSummaryScreenState();
}

class _SalesSummaryScreenState extends ConsumerState<SalesSummaryScreen> {
  final _pdfService = SalesSummaryPdfService();
  final _excelService = SalesSummaryExcelService();
  bool _exporting = false;

  late DateTimeRange _range;

  @override
  void initState() {
    super.initState();
    final end = DateTime.now();
    _range = DateTimeRange(
      start: DateTime(end.year, end.month, end.day).subtract(const Duration(days: 9)),
      end: end,
    );
  }

  bool _inRange(DateTime value) {
    final end = _range.end;
    return !value.isBefore(_range.start) &&
        !value.isAfter(DateTime(end.year, end.month, end.day, 23, 59, 59));
  }

  ({List<DailySales> days, double totalSales, int transactions,
      double averageOrder}) _compute() {
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
    var maxAmount = 0.0;
    for (final day in dayKeys) {
      final amount =
          byDay[day]!.fold<double>(0, (sum, sale) => sum + sale.totalAmount);
      if (amount > maxAmount) maxAmount = amount;
    }

    final days = <DailySales>[];
    for (final day in dayKeys) {
      final daySales = byDay[day]!;
      final amount =
          daySales.fold<double>(0, (sum, sale) => sum + sale.totalAmount);
      days.add(
        DailySales(
          date: day,
          label: DateFormat('dd MMM').format(day),
          amount: amount,
          transactionCount: daySales.length,
          maxAmount: maxAmount,
        ),
      );
    }

    final totalSales = days.fold<double>(0, (sum, day) => sum + day.amount);
    final transactions = days.fold<int>(
      0,
      (sum, day) => sum + day.transactionCount,
    );
    final averageOrder = transactions > 0 ? totalSales / transactions : 0.0;

    return (
      days: days,
      totalSales: totalSales,
      transactions: transactions,
      averageOrder: averageOrder,
    );
  }

  Future<void> _exportXlsx() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final data = _compute();
      await _excelService.saveSalesSummary(
        days: data.days,
        range: _range,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sales summary exported as XLSX')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportPdf() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final data = _compute();
      await _pdfService.saveSalesSummary(
        days: data.days,
        range: _range,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sales summary exported as PDF')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _compute();
    final summaryCards = [
      _SummaryCardData(label: 'Total Sales', amount: data.totalSales),
      _SummaryCardData(label: 'Transactions', amount: data.transactions),
      _SummaryCardData(label: 'Average Order', amount: data.averageOrder),
    ];
    final rangeLabel =
        '${DateFormat('dd MMM yyyy').format(_range.start)} – ${DateFormat('dd MMM yyyy').format(_range.end)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Summary'),
        actions: [
          const NotificationBell(),
          const SizedBox(width: 6),
          const ShopAvatar(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Row(
            children: [
              Text(
                rangeLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF667085),
                ),
              ),
              const Spacer(),
              _ExportButton(
                label: 'XLSX',
                icon: Icons.table_chart_outlined,
                color: const Color(0xFF059669),
                isBusy: _exporting,
                onTap: _exportXlsx,
              ),
              const SizedBox(width: 8),
              _ExportButton(
                label: 'PDF',
                icon: Icons.picture_as_pdf_rounded,
                color: const Color(0xFFF97316),
                isBusy: _exporting,
                onTap: _exportPdf,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var i = 0; i < summaryCards.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: _SummaryCard(data: summaryCards[i])),
              ],
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Daily Sales',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF101828),
            ),
          ),
          const SizedBox(height: 12),
          for (final day in data.days) ...[
            _DailySalesRow(day: day),
            const SizedBox(height: 8),
          ],
          if (data.days.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No sales in the last 10 days',
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

class _ExportButton extends StatelessWidget {
  const _ExportButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isBusy = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: isBusy ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isBusy)
              SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              )
            else
              Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCardData {
  const _SummaryCardData({required this.label, required this.amount});

  final String label;
  final num amount;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data});

  final _SummaryCardData data;

  @override
  Widget build(BuildContext context) {
    final formatted = data.label == 'Transactions'
        ? '${data.amount.toInt()}'
        : money(data.amount);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8DDD2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF98A2B3),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatted,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF101828),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailySalesRow extends StatelessWidget {
  const _DailySalesRow({required this.day});

  final DailySales day;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8DDD2)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: Color(0xFF101828),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${day.transactionCount} txns',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF98A2B3),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  money(day.amount),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: Color(0xFF101828),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Avg ${money(day.average)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF98A2B3),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 72,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: day.fraction,
                minHeight: 8,
                backgroundColor: const Color(0xFFFFE4BF),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF97316)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
