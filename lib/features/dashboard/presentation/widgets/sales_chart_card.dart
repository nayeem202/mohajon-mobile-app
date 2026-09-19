import 'package:flutter/material.dart';

import '../models/weekly_sales.dart';
import 'sales_line_chart.dart';

class SalesChartCard extends StatelessWidget {
  const SalesChartCard({
    super.key,
    this.data,
    this.onSalesOverviewTap,
    this.weekChangePercent,
  });

  final List<WeeklySalesData>? data;
  final VoidCallback? onSalesOverviewTap;
  final double? weekChangePercent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final sales = data ?? WeeklySalesData.demoData();
    final hasData = sales.any((d) => d.sales > 0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2F3028).withValues(alpha: 0.055),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(onSalesOverviewTap: onSalesOverviewTap),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: hasData
                ? SalesLineChart(data: sales)
                : _EmptyState(colors: colors),
          ),
          if (hasData) ...[
            const SizedBox(height: 16),
            _TrendIndicator(
              colors: colors,
              weekChangePercent: weekChangePercent,
            ),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({this.onSalesOverviewTap});

  final VoidCallback? onSalesOverviewTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          'This Week',
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onSalesOverviewTap,
          child: Text(
            'Sales Overview',
            style: TextStyle(
              color: colors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _TrendIndicator extends StatelessWidget {
  const _TrendIndicator({required this.colors, required this.weekChangePercent});

  final ColorScheme colors;
  final double? weekChangePercent;

  @override
  Widget build(BuildContext context) {
    final percent = weekChangePercent;
    final positive = (percent ?? 0) >= 0;
    final icon = positive
        ? Icons.trending_up_rounded
        : Icons.trending_down_rounded;
    final trendColor = percent == null
        ? const Color(0xFF77735F)
        : positive
        ? const Color(0xFF047857)
        : const Color(0xFFB42318);
    final label = percent == null
        ? '—'
        : '${percent >= 0 ? '+' : ''}${percent.abs().round()}%';
    final caption = percent == null
        ? 'No sales data from last week'
        : 'compared to last week';

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: trendColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            color: trendColor,
            size: 18,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: trendColor,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 40,
            color: colors.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            'No sales this week',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Start selling to see analytics.',
            style: TextStyle(
              color: colors.onSurfaceVariant.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
