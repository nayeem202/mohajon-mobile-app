import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/mohajon_warm_theme.dart';

mixin ReportExportMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool _exporting = false;

  bool get exporting => _exporting;

  Future<void> runExport({
    required Future<void> Function() task,
    required String message,
  }) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await task();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
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
}

DateTimeRange reportMonthRange(DateTime value) {
  final start = DateTime(value.year, value.month, 1);
  final end = DateTime(value.year, value.month + 1, 0);
  return DateTimeRange(start: start, end: end);
}

DateTimeRange reportPreviousMonthRange(DateTime value) {
  final prev = DateTime(value.year, value.month - 1, 1);
  final end = DateTime(value.year, value.month, 0);
  return DateTimeRange(start: prev, end: end);
}

DateTimeRange reportLast30DaysRange(DateTime value) {
  final end = DateTime(value.year, value.month, value.day);
  final start = end.subtract(const Duration(days: 29));
  return DateTimeRange(start: start, end: end);
}

String reportRangeLabel(DateTimeRange range) =>
    '${DateFormat('dd MMM yyyy').format(range.start)} - ${DateFormat('dd MMM yyyy').format(range.end)}';

/// Shared premium card background: warm cream gradient + gold border.
BoxDecoration reportCardDecoration({double radius = 14}) {
  return BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [MohajonWarm.card, Color(0xFFFFFBEF)],
    ),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: MohajonWarm.goldBorder),
  );
}

class ReportSummaryCard extends StatelessWidget {
  const ReportSummaryCard({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: reportCardDecoration(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: MohajonWarm.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: valueColor,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class ReportRangeSelector extends StatelessWidget {
  const ReportRangeSelector({
    required this.range,
    required this.onPickRange,
    required this.onThisMonth,
    required this.onLastMonth,
    required this.onLast30Days,
  });

  final DateTimeRange range;
  final VoidCallback onPickRange;
  final VoidCallback onThisMonth;
  final VoidCallback onLastMonth;
  final VoidCallback onLast30Days;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: reportCardDecoration(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  Icons.date_range_rounded,
                  size: 15,
                  color: MohajonWarm.ink,
                ),
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'Date Range',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: MohajonWarm.ink,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onPickRange,
                icon: const Icon(Icons.calendar_month_rounded, size: 18),
                label: const Text('Change'),
                style: TextButton.styleFrom(
                  foregroundColor: MohajonWarm.goldText,
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            reportRangeLabel(range),
            style: const TextStyle(
              color: MohajonWarm.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PresetChip(
                  label: 'This Month',
                  onTap: onThisMonth,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PresetChip(
                  label: 'Last Month',
                  onTap: onLastMonth,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PresetChip(
                  label: 'Last 30 Days',
                  onTap: onLast30Days,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: MohajonWarm.tintYellow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: MohajonWarm.primary.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: MohajonWarm.goldText,
          ),
        ),
      ),
    );
  }
}

class ReportExportButton extends StatelessWidget {
  const ReportExportButton({
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
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isBusy ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isBusy)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              else
                Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReportRowTile extends StatelessWidget {
  const ReportRowTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.titleColor = const Color(0xFF101828),
    this.icon,
    this.iconColor = const Color(0xFFF97316),
  });

  final String title;
  final String subtitle;
  final String trailing;
  final Color titleColor;
  final IconData? icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: reportCardDecoration(radius: 14),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
          Text(
            trailing,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: MohajonWarm.ink,
            ),
          ),
        ],
      ),
    );
  }
}
