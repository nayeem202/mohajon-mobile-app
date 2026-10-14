import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/utils/app_error.dart';
import '../../settings/providers/shop_profile_providers.dart';
import '../models/table_report.dart';

/// Shared report identity block. Every report now starts with the same shop
/// context, so the screen and its exported document feel like one product.
class ReportBrandStrip extends ConsumerWidget {
  const ReportBrandStrip({
    super.key,
    required this.title,
    this.subtitle = 'Live business insight, ready to export',
    this.icon = Icons.insights_rounded,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final shop = ref.watch(shopProfileProvider).value;
    final logo = (shop?.reportLogoPath ?? '').trim();
    final shopName = (shop?.shopName ?? '').trim();
    return Container(
      padding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MohajonWarm.ink, Color(0xFF414537), MohajonWarm.goldText],
          stops: [0, 0.65, 1],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: MohajonWarm.ink.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -22,
            top: -34,
            child: Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.09),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
                child: logo.isEmpty
                    ? Icon(icon, color: MohajonWarm.orange, size: 25)
                    : AppImage(
                        path: logo,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) =>
                            Icon(icon, color: MohajonWarm.orange, size: 25),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizedReportText(title, l10n),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      localizedReportText(subtitle, l10n),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.76),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (shopName.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Text(
                          shopName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

mixin ReportExportMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool _exportingXlsx = false;
  bool _exportingPdf = false;

  bool get exportingXlsx => _exportingXlsx;
  bool get exportingPdf => _exportingPdf;

  Future<void> runExport({
    required Future<void> Function() task,
    required String message,
    required bool isXlsx,
  }) async {
    if (isXlsx && _exportingXlsx) return;
    if (!isXlsx && _exportingPdf) return;
    setState(() {
      if (isXlsx) {
        _exportingXlsx = true;
      } else {
        _exportingPdf = true;
      }
    });
    try {
      await task();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyErrorMessage(error, l10n: AppLocalizations.of(context)),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          if (isXlsx) {
            _exportingXlsx = false;
          } else {
            _exportingPdf = false;
          }
        });
      }
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
    super.key,
    required this.label,
    required this.value,
    required this.valueColor,
    this.subtitle,
    this.icon,
  });

  final String label;
  final String value;
  final Color valueColor;
  final String? subtitle;
  final IconData? icon;

  IconData _icon() {
    final explicit = icon;
    if (explicit != null) return explicit;
    final l = label.toLowerCase();
    if (l.contains('profit')) return Icons.trending_up_rounded;
    if (l.contains('revenue') || l.contains('sales') || l.contains('vatable')) {
      return Icons.attach_money_rounded;
    }
    if (l.contains('expense')) return Icons.receipt_long_rounded;
    if (l.contains('pay')) return Icons.payments_rounded;
    if (l.contains('receive')) return Icons.call_received_rounded;
    if (l.contains('method') ||
        l.contains('transaction') ||
        l.contains('active')) {
      return Icons.bolt_rounded;
    }
    if (l.contains('due') || l.contains('rate')) return Icons.percent_rounded;
    if (l.contains('vat') || l.contains('total')) {
      return Icons.calculate_rounded;
    }
    return Icons.bar_chart_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final icon = _icon();
    final accent = valueColor;
    final localizedLabel = localizedReportText(
      label,
      AppLocalizations.of(context),
    );
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
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [accent, accent.withValues(alpha: 0.65)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.28),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(icon, size: 17, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    localizedLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      color: MohajonWarm.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: valueColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: MohajonWarm.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReportRangeSelector extends StatelessWidget {
  const ReportRangeSelector({
    super.key,
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
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MohajonWarm.card, Color(0xFFFFFBEF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MohajonWarm.goldBorder),
        boxShadow: [
          BoxShadow(
            color: MohajonWarm.ink.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
              Expanded(
                child: Text(
                  l10n.t('dateRange'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: MohajonWarm.ink,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onPickRange,
                icon: const Icon(Icons.calendar_month_rounded, size: 18),
                label: Text(l10n.t('changeLabel')),
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
                  label: l10n.t('thisMonth'),
                  onTap: onThisMonth,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PresetChip(
                  label: l10n.t('lastMonth'),
                  onTap: onLastMonth,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PresetChip(
                  label: l10n.t('last30Days'),
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
    super.key,
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
    super.key,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.titleColor = const Color(0xFF101828),
    this.trailingColor = MohajonWarm.ink,
    this.icon,
    this.iconColor = const Color(0xFFF97316),
  });

  final String title;
  final String subtitle;
  final String trailing;
  final Color titleColor;
  final Color trailingColor;
  final IconData? icon;
  final Color iconColor;

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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MohajonWarm.goldBorder),
        boxShadow: [
          BoxShadow(
            color: MohajonWarm.ink.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [iconColor, iconColor.withValues(alpha: 0.6)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: iconColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, size: 20, color: Colors.white),
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
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: trailingColor,
            ),
          ),
        ],
      ),
    );
  }
}
