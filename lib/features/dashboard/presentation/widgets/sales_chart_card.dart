import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/models/sale.dart';
import '../../../customers/providers/customer_providers.dart';
import '../../services/sales_trend_api_service.dart';
import '../models/weekly_sales.dart';
import 'sales_line_chart.dart';

enum _SalesRange { threeMonths, sixMonths, oneYear, custom }

enum _BucketSize { day, week, month }

class SalesChartCard extends ConsumerStatefulWidget {
  const SalesChartCard({super.key, this.onSalesOverviewTap});

  final VoidCallback? onSalesOverviewTap;

  @override
  ConsumerState<SalesChartCard> createState() => _SalesChartCardState();
}

class _SalesChartCardState extends ConsumerState<SalesChartCard> {
  _SalesRange _range = _SalesRange.sixMonths;
  DateTimeRange? _customRange;

  Future<void> _chooseCustomRange() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial =
        _customRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month - 5, today.day),
          end: today,
        );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: today.subtract(const Duration(days: 3659)),
      lastDate: today,
      initialDateRange: DateTimeRange(
        start: initial.start.isAfter(today) ? today : initial.start,
        end: initial.end.isAfter(today) ? today : initial.end,
      ),
      helpText: AppLocalizations.of(context).t('chooseSalesPeriod'),
      saveText: AppLocalizations.of(context).t('apply'),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _customRange = DateTimeRange(
        start: DateTime(
          picked.start.year,
          picked.start.month,
          picked.start.day,
        ),
        end: DateTime(picked.end.year, picked.end.month, picked.end.day),
      );
      _range = _SalesRange.custom;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final sales = ref.watch(salesStreamProvider).value ?? const <Sale>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final range = _resolveRange(today);
    final bucket = _bucketFor(range);
    final groupBy = switch (bucket) {
      _BucketSize.day => 'day',
      _BucketSize.week => 'week',
      _BucketSize.month => 'month',
    };
    final remoteTrend = ref
        .watch(
          salesTrendProvider((
            from: range.start,
            to: range.endExclusive.subtract(const Duration(days: 1)),
            groupBy: groupBy,
          )),
        )
        .asData
        ?.value;
    final filtered = sales.where(
      (sale) =>
          !sale.isDeleted &&
          !sale.createdAt.isBefore(range.start) &&
          sale.createdAt.isBefore(range.endExclusive),
    );
    final previousStart = range.start.subtract(
      range.endExclusive.difference(range.start),
    );
    final previousSales = sales.where(
      (sale) =>
          !sale.isDeleted &&
          !sale.createdAt.isBefore(previousStart) &&
          sale.createdAt.isBefore(range.start),
    );
    final localTotal = filtered.fold<double>(
      0,
      (sum, sale) => sum + sale.totalAmount,
    );
    final localPreviousTotal = previousSales.fold<double>(
      0,
      (sum, sale) => sum + sale.totalAmount,
    );
    final localChange = localPreviousTotal > 0
        ? ((localTotal - localPreviousTotal) / localPreviousTotal) * 100
        : null;
    final total = remoteTrend?.totalSales ?? localTotal;
    final change = remoteTrend != null
        ? remoteTrend.changePercent
        : localChange;
    final chartData = _makeBuckets(
      filtered.toList(),
      range,
      bucket,
      l10n.locale.languageCode,
      remotePoints: remoteTrend?.points,
    );
    final hasSales = total > 0;

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
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.t('salesOverview'),
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (widget.onSalesOverviewTap != null)
                IconButton(
                  onPressed: widget.onSalesOverviewTap,
                  tooltip: l10n.t('salesSummary'),
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.open_in_new_rounded,
                    size: 18,
                    color: colors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _rangeChip(l10n.t('threeMonths'), _SalesRange.threeMonths),
              _rangeChip(l10n.t('sixMonths'), _SalesRange.sixMonths),
              _rangeChip(l10n.t('oneYear'), _SalesRange.oneYear),
              _rangeChip(
                _customRange == null
                    ? l10n.t('customRange')
                    : _formatRange(_customRange!, l10n.locale.languageCode),
                _SalesRange.custom,
                onTap: _chooseCustomRange,
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 190,
            child: hasSales
                ? SalesLineChart(data: chartData)
                : _EmptyState(colors: colors, text: l10n.t('noSalesInPeriod')),
          ),
          if (hasSales) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: l10n.t('salesInPeriod'),
                    value: _formatMoney(total, l10n.locale.languageCode),
                    colors: colors,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Metric(
                    label: l10n.t('vsPreviousPeriod'),
                    value: change == null
                        ? '—'
                        : '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}%',
                    colors: colors,
                    valueColor: change == null
                        ? null
                        : change >= 0
                        ? const Color(0xFF047857)
                        : const Color(0xFFB42318),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _rangeChip(String label, _SalesRange range, {VoidCallback? onTap}) {
    final selected = _range == range;
    final colors = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      selected: selected,
      onSelected: (_) {
        if (onTap != null) {
          onTap();
        } else {
          setState(() => _range = range);
        }
      },
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: selected ? colors.onPrimary : colors.onSurfaceVariant,
      ),
      selectedColor: colors.primary,
      backgroundColor: colors.surfaceContainerHighest.withValues(alpha: 0.55),
      side: BorderSide(
        color: selected ? colors.primary : colors.outlineVariant,
      ),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 3),
    );
  }

  _ResolvedRange _resolveRange(DateTime today) {
    if (_range == _SalesRange.custom && _customRange != null) {
      final custom = _customRange!;
      return _ResolvedRange(
        custom.start,
        custom.end.add(const Duration(days: 1)),
      );
    }
    final months = switch (_range) {
      _SalesRange.threeMonths => 3,
      _SalesRange.oneYear => 12,
      _ => 6,
    };
    return _ResolvedRange(
      DateTime(today.year, today.month - months + 1),
      today.add(const Duration(days: 1)),
    );
  }

  _BucketSize _bucketFor(_ResolvedRange range) {
    if (_range != _SalesRange.custom) return _BucketSize.month;
    final days = range.endExclusive.difference(range.start).inDays;
    if (days <= 45) return _BucketSize.day;
    if (days <= 180) return _BucketSize.week;
    return _BucketSize.month;
  }

  List<WeeklySalesData> _makeBuckets(
    List<Sale> sales,
    _ResolvedRange range,
    _BucketSize size,
    String language, {
    List<SalesTrendPoint>? remotePoints,
  }) {
    DateTime cursor;
    DateTime next(DateTime date) => switch (size) {
      _BucketSize.day => date.add(const Duration(days: 1)),
      _BucketSize.week => date.add(const Duration(days: 7)),
      _BucketSize.month => DateTime(date.year, date.month + 1),
    };
    DateTime bucketStart(DateTime date) => switch (size) {
      _BucketSize.day => DateTime(date.year, date.month, date.day),
      _BucketSize.week => DateTime(
        date.year,
        date.month,
        date.day,
      ).subtract(Duration(days: date.weekday - 1)),
      _BucketSize.month => DateTime(date.year, date.month),
    };
    cursor = bucketStart(range.start);
    final totals = <DateTime, double>{};
    while (cursor.isBefore(range.endExclusive)) {
      totals[cursor] = 0;
      cursor = next(cursor);
    }
    if (remotePoints != null) {
      for (final point in remotePoints) {
        totals[bucketStart(point.periodStart)] = point.totalSales;
      }
    } else {
      for (final sale in sales) {
        final key = bucketStart(sale.createdAt);
        totals[key] = (totals[key] ?? 0) + sale.totalAmount;
      }
    }
    final keys = totals.keys.toList()..sort();
    return keys.map((date) {
      final label = switch (size) {
        _BucketSize.day => '${date.day}/${date.month}',
        _BucketSize.week => '${date.day}/${date.month}',
        _BucketSize.month => _monthLabel(date.month, language),
      };
      final full = switch (size) {
        _BucketSize.day => _formatDate(date, language, includeYear: true),
        _BucketSize.week =>
          '${_formatDate(date, language)} – ${_formatDate(next(date).subtract(const Duration(days: 1)), language, includeYear: true)}',
        _BucketSize.month => '${_monthName(date.month, language)} ${date.year}',
      };
      return WeeklySalesData(
        dayLabel: label,
        fullDayName: full,
        sales: totals[date] ?? 0,
      );
    }).toList();
  }

  String _monthLabel(int month, String language) {
    const en = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const bn = [
      'জানু',
      'ফেব',
      'মার্চ',
      'এপ্রি',
      'মে',
      'জুন',
      'জুল',
      'আগ',
      'সেপ্টে',
      'অক্টো',
      'নভে',
      'ডিসে',
    ];
    return (language == 'bn' ? bn : en)[month - 1];
  }

  String _monthName(int month, String language) {
    const en = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const bn = [
      'জানুয়ারি',
      'ফেব্রুয়ারি',
      'মার্চ',
      'এপ্রিল',
      'মে',
      'জুন',
      'জুলাই',
      'আগস্ট',
      'সেপ্টেম্বর',
      'অক্টোবর',
      'নভেম্বর',
      'ডিসেম্বর',
    ];
    return (language == 'bn' ? bn : en)[month - 1];
  }

  String _formatDate(
    DateTime date,
    String language, {
    bool includeYear = false,
  }) =>
      '${date.day} ${_monthLabel(date.month, language)}${includeYear ? ' ${date.year}' : ''}';

  String _formatRange(DateTimeRange range, String language) =>
      '${_formatDate(range.start, language)} – ${_formatDate(range.end, language, includeYear: true)}';

  String _formatMoney(double value, String language) {
    final amount = NumberFormat('#,##,##0.##').format(value);
    return '৳$amount';
  }
}

class _ResolvedRange {
  const _ResolvedRange(this.start, this.endExclusive);
  final DateTime start;
  final DateTime endExclusive;
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.colors,
    this.valueColor,
  });
  final String label;
  final String value;
  final ColorScheme colors;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    decoration: BoxDecoration(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: valueColor ?? colors.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.colors, required this.text});
  final ColorScheme colors;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.analytics_outlined,
          size: 38,
          color: colors.onSurfaceVariant.withValues(alpha: 0.35),
        ),
        const SizedBox(height: 10),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
