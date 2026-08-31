import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/sale.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/money.dart';
import '../../customers/providers/customer_providers.dart';
import '../models/daily_sales.dart';
import '../services/sales_summary_excel_service.dart';
import '../services/sales_summary_pdf_service.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';

const _dailyBarPalette = <Color>[
  Color(0xFFF5B731), // gold
  Color(0xFF047857), // green
  Color(0xFFEA580C), // orange
  Color(0xFF0D9488), // teal
  Color(0xFF6366F1), // indigo
  Color(0xFFE11D48), // rose
];

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
    for (var i = 0; i < dayKeys.length; i++) {
      final day = dayKeys[i];
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
          color: _dailyBarPalette[i % _dailyBarPalette.length],
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

    return Theme(
      data: MohajonWarm.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Sales Summary',
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
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _RangePill(label: rangeLabel),
                    ),
                    const SizedBox(width: 8),
                    _ExportButton(
                      label: 'XLSX',
                      icon: Icons.table_chart_outlined,
                      color: MohajonWarm.green,
                      isBusy: _exporting,
                      onTap: _exportXlsx,
                    ),
                    const SizedBox(width: 8),
                    _ExportButton(
                      label: 'PDF',
                      icon: Icons.picture_as_pdf_rounded,
                      color: MohajonWarm.orange,
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
                const SizedBox(height: 22),
                const _SectionLabel(label: 'Daily Sales'),
                const SizedBox(height: 14),
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
          ),
        ),
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

  (Color, IconData) _accent() {
    switch (data.label) {
      case 'Transactions':
        return (MohajonWarm.green, Icons.receipt_long_rounded);
      case 'Average Order':
        return (MohajonWarm.orange, Icons.shopping_cart_rounded);
      default:
        return (MohajonWarm.goldText, Icons.trending_up_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatted = data.label == 'Transactions'
        ? '${data.amount.toInt()}'
        : money(data.amount);
    final (accent, icon) = _accent();
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MohajonWarm.card, Color(0xFFFFFBEF)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MohajonWarm.goldBorder),
        boxShadow: [
          BoxShadow(
            color: MohajonWarm.ink.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Stack(
          children: [
            Positioned(
              top: -18,
              right: -18,
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.1),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [accent, accent.withValues(alpha: 0.65)],
                      ),
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(icon, size: 18, color: Colors.white),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    data.label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: MohajonWarm.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    formatted,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: accent,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RangePill extends StatelessWidget {
  const _RangePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: MohajonWarm.card.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MohajonWarm.goldBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_month_rounded,
            size: 16,
            color: MohajonWarm.goldText,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: MohajonWarm.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [MohajonWarm.primary, MohajonWarm.primarySoft],
            ),
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          child: const Icon(
            Icons.bar_chart_rounded,
            size: 15,
            color: MohajonWarm.ink,
          ),
        ),
        const SizedBox(width: 9),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.9,
            color: MohajonWarm.ink.withValues(alpha: 0.6),
          ),
        ),
      ],
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MohajonWarm.card, Color(0xFFFFFBEF)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MohajonWarm.goldBorder),
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
                    color: MohajonWarm.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${day.transactionCount} txns',
                  style: const TextStyle(
                    fontSize: 11,
                    color: MohajonWarm.muted,
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
                    color: MohajonWarm.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Avg ${money(day.average)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: MohajonWarm.muted,
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
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: day.fraction,
                minHeight: 8,
                backgroundColor: day.color.withValues(alpha: 0.14),
                valueColor: AlwaysStoppedAnimation<Color>(day.color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
