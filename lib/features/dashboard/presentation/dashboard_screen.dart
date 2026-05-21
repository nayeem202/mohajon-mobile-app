import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/utils/money.dart';
import '../providers/dashboard_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final summary = ref.watch(dashboardProvider);
    final sync = ref.watch(syncStateProvider);
    return Scaffold(
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
                _MetricCard(
                  label: l10n.t('offlineReady'),
                  value: '${sync.pendingCount} pending',
                  icon: Icons.cloud_upload_rounded,
                  color: const Color(0xFF7A5AF8),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 760;
                final sections = [
                  _Section(
                    title: l10n.t('topSelling'),
                    icon: Icons.local_fire_department_rounded,
                    children: summary.topSelling.isEmpty
                        ? [const ListTile(title: Text('No sales yet'))]
                        : [
                            for (
                              var index = 0;
                              index < summary.topSelling.length;
                              index++
                            )
                              ListTile(
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.1),
                                  child: Text('${index + 1}'),
                                ),
                                title: Text(summary.topSelling[index]),
                              ),
                          ],
                  ),
                  _Section(
                    title: l10n.t('lowStock'),
                    icon: Icons.warning_amber_rounded,
                    children: summary.lowStock.isEmpty
                        ? [const ListTile(title: Text('No low stock products'))]
                        : summary.lowStock
                              .map(
                                (product) => ListTile(
                                  title: Text(product.nameEn),
                                  subtitle: Text(product.category),
                                  trailing: _StockPill(
                                    value: product.stockQty.toString(),
                                  ),
                                ),
                              )
                              .toList(),
                  ),
                ];
                if (!wide) {
                  return Column(
                    children: [for (final section in sections) section],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: sections[0]),
                    const SizedBox(width: 16),
                    Expanded(child: sections[1]),
                  ],
                );
              },
            ),
            _Section(
              title: l10n.t('monthlySummary'),
              icon: Icons.bar_chart_rounded,
              children: [
                SizedBox(
                  height: 130,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final value in summary.monthlySales)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: FractionallySizedBox(
                              heightFactor:
                                  summary.monthlySales.reduce(
                                        (a, b) => a > b ? a : b,
                                      ) ==
                                      0
                                  ? 0.02
                                  : (value /
                                            summary.monthlySales.reduce(
                                              (a, b) => a > b ? a : b,
                                            ))
                                        .clamp(0.02, 1),
                              alignment: Alignment.bottomCenter,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Theme.of(context).colorScheme.primary,
                                      Theme.of(context).colorScheme.secondary,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.sizeOf(context).width > 700
          ? 220
          : (MediaQuery.sizeOf(context).width - 44) / 2,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
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

    return SizedBox(
      width: MediaQuery.sizeOf(context).width > 700
          ? 220
          : (MediaQuery.sizeOf(context).width - 44) / 2,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    const Align(
                      alignment: Alignment.center,
                      child: Icon(Icons.query_stats_rounded, color: Colors.white),
                    ),
                    Align(
                      alignment: Alignment.topRight,
                      child: Icon(
                        summary.grossProfit >= summary.grossLoss
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                ratioText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'P/L ratio',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Net ${money(summary.netProfit)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: netColor,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
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
      padding: const EdgeInsets.all(22),
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
              size: 132,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
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
              const SizedBox(height: 18),
              const Text(
                'Today at a glance',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${money(summary.todaySales)} sold today • ${sync.pendingCount} records waiting for cloud',
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

class _StockPill extends StatelessWidget {
  const _StockPill({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        value,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    required this.icon,
  });

  final String title;
  final List<Widget> children;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(icon, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}
