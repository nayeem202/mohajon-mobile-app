import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/product.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../providers/dashboard_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final summary = ref.watch(dashboardProvider);
    final sync = ref.watch(syncStateProvider);
    return LoadingOverlay(
      loading: sync.phase == SyncPhase.syncing,
      label: 'Syncing data...',
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.t('dashboard')),
          actions: [
            IconButton(
              tooltip: l10n.t('syncNow'),
              onPressed: sync.phase == SyncPhase.syncing
                  ? null
                  : () => ref.read(syncStateProvider.notifier).syncNow(),
              icon: sync.phase == SyncPhase.syncing
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => ref.read(syncStateProvider.notifier).syncNow(),
          child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            _HeroPanel(summary: summary, sync: sync),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricCard(
                  label: l10n.t('todaySales'),
                  value: money(summary.todaySales),
                  icon: Icons.trending_up_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                _MetricCard(
                  label: l10n.t('totalDue'),
                  value: money(summary.totalDue),
                  icon: Icons.account_balance_wallet_rounded,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                _MetricCard(
                  label: l10n.t('customersDue'),
                  value: '${summary.customerDueCount}',
                  icon: Icons.groups_rounded,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                _RatioMetricCard(summary: summary),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 760;
                final topSellingCard = _TopSellingProductsCard(
                  items: summary.topSelling,
                );
                if (!wide) {
                  return topSellingCard;
                }
                return topSellingCard;
              },
            ),
            const SizedBox(height: 16),
            _DayWiseSummaryCard(summary: summary),
          ],
        ),
      ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  static const double _cardWidth = 190;
  static const double _cardHeight = 128;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.sizeOf(context).width > 700
          ? _cardWidth
          : (MediaQuery.sizeOf(context).width - 44) / 2,
      height: _cardHeight,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RatioMetricCard extends StatelessWidget {
  const _RatioMetricCard({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final ratioText = summary.profitLossRatio == double.infinity
        ? '∞'
        : summary.profitLossRatio.toStringAsFixed(2);
    final netColor = summary.netProfit >= 0
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;
    final trendIcon = summary.grossProfit >= summary.grossLoss
        ? Icons.north_east_rounded
        : Icons.south_east_rounded;

    return SizedBox(
      width: MediaQuery.sizeOf(context).width > 700
          ? _MetricCard._cardWidth
          : (MediaQuery.sizeOf(context).width - 44) / 2,
      height: _MetricCard._cardHeight,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: netColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.balance_rounded,
                      color: netColor,
                      size: 17,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    trendIcon,
                    size: 16,
                    color: netColor,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                ratioText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                'P/L ratio',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopSellingProductsCard extends StatelessWidget {
  const _TopSellingProductsCard({required this.items});

  final List<TopSellingProduct> items;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.local_fire_department_rounded,
                    color: colors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Top selling products',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Best movers in the shop',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (items.isEmpty)
              Text(
                'No sales yet',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              )
            else
              for (var index = 0; index < items.length; index++) ...[
                if (index != 0) const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: index == 0
                            ? colors.primary.withValues(alpha: 0.12)
                            : colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: index == 0 ? colors.primary : colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        items[index].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _formatQuantity(items[index].quantity),
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
          ],
        ),
      ),
    );
  }
}

class _DayWiseSummaryCard extends StatelessWidget {
  const _DayWiseSummaryCard({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final days = summary.dayWiseSales;
    final maxSales = days.fold<double>(
      0,
      (maxValue, day) => day.sales > maxValue ? day.sales : maxValue,
    );
    final totalSales = days.fold<double>(0, (sum, day) => sum + day.sales);
    final peakDay = days.isEmpty
        ? null
        : days.reduce((a, b) => a.sales >= b.sales ? a : b);
    final subtitle = peakDay == null || peakDay.sales <= 0
        ? 'No sales recorded in the last 7 days'
        : 'Peak day: ${peakDay.label}';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surfaceContainerHighest.withValues(alpha: 0.92),
            colors.primary.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.primary.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [colors.primary, colors.secondary],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.query_stats_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Day-wise sales summary',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${days.length} days',
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryStat(
                      label: '7-day total',
                      value: money(totalSales),
                      accent: colors.primary,
                    ),
                  ),
                  Container(width: 1, height: 34, color: colors.outlineVariant),
                  Expanded(
                    child: _SummaryStat(
                      label: 'Today',
                      value: money(summary.todaySales),
                      accent: colors.tertiary,
                    ),
                  ),
                  if (peakDay != null) ...[
                    Container(width: 1, height: 34, color: colors.outlineVariant),
                    Expanded(
                      child: _SummaryStat(
                        label: 'Peak',
                        value: peakDay.label,
                        accent: colors.secondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            for (var index = 0; index < days.length; index++) ...[
              _DaySalesRow(
                summary: days[index],
                maxSales: maxSales,
                isLast: index == days.length - 1,
              ),
              if (index != days.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: accent,
              ),
        ),
      ],
    );
  }
}

class _DaySalesRow extends StatelessWidget {
  const _DaySalesRow({
    required this.summary,
    required this.maxSales,
    required this.isLast,
  });

  final DaySalesSummary summary;
  final double maxSales;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fraction = maxSales <= 0
        ? 0.02
        : (summary.sales / maxSales).clamp(0.02, 1.0).toDouble();
    final barColor = summary.isToday ? colors.primary : colors.secondary;

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: summary.isToday
                    ? colors.primary.withValues(alpha: 0.12)
                    : colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: summary.isToday
                      ? colors.primary.withValues(alpha: 0.24)
                      : colors.outlineVariant,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    summary.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: summary.isToday
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${summary.date.day}',
                    style: TextStyle(
                      fontSize: 10,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          summary.isToday ? 'Today' : summary.label,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      Text(
                        money(summary.sales),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: barColor,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      height: 10,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: colors.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: fraction,
                            alignment: Alignment.centerLeft,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [barColor, colors.tertiary],
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Divider(height: 1, color: colors.outlineVariant),
          ),
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.summary, required this.sync});

  final DashboardSummary summary;
  final SyncState sync;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = switch (sync.phase) {
      SyncPhase.syncing => 'Syncing cloud data',
      SyncPhase.offline => 'Offline mode active',
      SyncPhase.firebaseNotConfigured => 'Firebase setup pending',
      SyncPhase.failed => 'Sync needs attention',
      SyncPhase.idle => 'All systems ready',
    };
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            top: -28,
            child: Icon(
              Icons.storefront_rounded,
              size: 112,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Today at a glance',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                      ),
                    ),
                  ),
                  if (sync.pendingCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${sync.pendingCount} pending',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${money(summary.todaySales)} sold today',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatQuantity(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}
