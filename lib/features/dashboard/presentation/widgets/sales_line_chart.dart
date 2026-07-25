import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/weekly_sales.dart';

class SalesLineChart extends StatelessWidget {
  const SalesLineChart({
    super.key,
    required this.data,
    this.animate = true,
  });

  final List<WeeklySalesData> data;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final maxSales = data.fold<double>(
      0,
      (max, d) => d.sales > max ? d.sales : max,
    );
    final effectiveMax = maxSales > 0 ? maxSales * 1.25 : 10000.0;

    if (data.isEmpty) return const SizedBox.shrink();

    return RepaintBoundary(
      child: LineChart(
        _chartData(colors, effectiveMax),
        duration: animate ? const Duration(milliseconds: 700) : Duration.zero,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  LineChartData _chartData(ColorScheme colors, double maxY) {
    return LineChartData(
      minX: 0,
      maxX: (data.length - 1).toDouble(),
      minY: 0,
      maxY: maxY,
      clipData: const FlClipData.all(),
      gridData: _gridData(colors, maxY),
      titlesData: _titlesData(colors, maxY),
      borderData: FlBorderData(show: false),
      lineBarsData: [_lineBarData(colors, maxY)],
      lineTouchData: _touchData(colors),
    );
  }

  FlGridData _gridData(ColorScheme colors, double maxY) {
    return FlGridData(
      show: true,
      drawHorizontalLine: true,
      drawVerticalLine: false,
      horizontalInterval: maxY / 5,
      getDrawingHorizontalLine: (_) => FlLine(
        color: colors.outlineVariant.withValues(alpha: 0.5),
        strokeWidth: 1,
      ),
    );
  }

  FlTitlesData _titlesData(ColorScheme colors, double maxY) {
    return FlTitlesData(
      show: true,
      topTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      rightTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 48,
          getTitlesWidget: (value, meta) {
            if (value == 0) return _yLabel('0', colors);
            final k = (value / 1000).floor();
            return _yLabel('${k}k', colors);
          },
          interval: maxY / 5,
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          interval: 1,
          getTitlesWidget: (value, meta) {
            final idx = value.toInt();
            if (idx < 0 || idx >= data.length) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                data[idx].dayLabel,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _yLabel(String text, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Text(
        text,
        style: TextStyle(
          color: colors.onSurfaceVariant.withValues(alpha: 0.6),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  LineChartBarData _lineBarData(ColorScheme colors, double maxY) {
    final primaryOrange = const Color(0xFFFF6B00);
    return LineChartBarData(
      spots: List.generate(data.length, (i) {
        final value = data[i].sales;
        final y = value > 0 ? value : maxY * 0.02;
        return FlSpot(i.toDouble(), y);
      }),
      isCurved: true,
      preventCurveOverShooting: true,
      color: primaryOrange,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: primaryOrange.withValues(alpha: 0.12),
        cutOffY: 0,
        spotsLine: BarAreaSpotsLine(
          show: true,
          flLineStyle: FlLine(
            color: primaryOrange.withValues(alpha: 0.25),
            strokeWidth: 1,
          ),
        ),
      ),
    );
  }

  LineTouchData _touchData(ColorScheme colors) {
    final primaryOrange = const Color(0xFFFF6B00);
    return LineTouchData(
      enabled: true,
      handleBuiltInTouches: true,
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (_) => const Color(0xFF1C1917),
        tooltipRoundedRadius: 10,
        tooltipPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        tooltipMargin: 12,
        getTooltipItems: (touchedSpots) {
          return touchedSpots.map((spot) {
            final idx = spot.spotIndex;
            final day = idx < data.length ? data[idx] : null;
            if (day == null) return null;
            return LineTooltipItem(
              '${day.fullDayName}\n',
              TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
              children: [
                TextSpan(
                  text: '৳${_formatAmount(day.sales)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            );
          }).toList();
        },
      ),
      getTouchedSpotIndicator: (barData, spotIndexes) {
        return spotIndexes.map((idx) {
          return TouchedSpotIndicatorData(
            FlLine(
              color: primaryOrange.withValues(alpha: 0.3),
              strokeWidth: 1,
            ),
            FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 6,
                  color: Colors.white,
                  strokeWidth: 3,
                  strokeColor: primaryOrange,
                );
              },
            ),
          );
        }).toList();
      },
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}k';
    }
    return amount.toStringAsFixed(0);
  }
}
