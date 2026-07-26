import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/product.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../profile/models/profile.dart';
import '../../profile/presentation/profile_overview_screen.dart';
import '../../pos/presentation/sales_history_screen.dart';
import '../../profile/providers/profile_providers.dart';
import '../presentation/low_stock_products_screen.dart';
import '../providers/dashboard_providers.dart';
import 'models/weekly_sales.dart';
import 'widgets/home_shortcut_section.dart';
import 'widgets/sales_chart_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardProvider);
    final sync = ref.watch(syncStateProvider);
    final profile = ref.watch(profileProvider);
    return LoadingOverlay(
      loading: sync.phase == SyncPhase.syncing,
      label: 'Syncing data...',
      child: Scaffold(
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => ref.read(syncStateProvider.notifier).syncNow(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              children: [
                _HomeTopBar(
                  profile: profile,
                  onAvatarTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ProfileOverviewScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _GreetingPanel(
                  summary: summary,
                  name: profile?.ownerName ?? '',
                ),
                const SizedBox(height: 20),
                const HomeShortcutSection(),
                const SizedBox(height: 20),
                _OverviewStats(summary: summary),
                const SizedBox(height: 20),
                SalesChartCard(
                  data: summary.dayWiseSales.map((d) => WeeklySalesData(
                    dayLabel: d.label,
                    fullDayName: DateFormat('EEEE').format(d.date),
                    sales: d.sales,
                  )).toList(),
                ),
                const SizedBox(height: 20),
                _RecentSalesCard(sales: summary.recentSales),
                const SizedBox(height: 20),
                _LowStockAlert(products: summary.lowStock),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({required this.onAvatarTap, this.profile});

  final VoidCallback onAvatarTap;
  final Profile? profile;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name = profile?.ownerName ?? '';
    final imagePath = profile?.imagePath;

    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.storefront_rounded,
            color: Colors.white,
            size: 17,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            AppConstants.appName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: colors.onSurface,
            ),
          ),
        ),
        const NotificationBell(),
        const SizedBox(width: 14),
        AppAvatar(name: name, imagePath: imagePath, onTap: onAvatarTap, radius: 17),
      ],
    );
  }
}

class _GreetingPanel extends StatelessWidget {
  const _GreetingPanel({required this.summary, required this.name});

  final DashboardSummary summary;
  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final date = DateFormat('EEEE, MMMM d, y').format(DateTime.now());
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  date,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wb_sunny_outlined,
                  color: Colors.white,
                  size: 21,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Good day, $name!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your shop is doing great today',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _HeroMetric(
                    label: "Today's Sales",
                    value: money(summary.todaySales),
                    footnote: _salesChangeFootnote(summary),
                  ),
                ),
                const SizedBox(width: 16),
                _HeroMetric(
                  label: 'Transactions',
                  value: '${summary.todayTransactionCount}',
                  alignEnd: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _salesChangeFootnote(DashboardSummary summary) {
    final yesterday = summary.yesterdaySales;
    final today = summary.todaySales;
    if (yesterday == 0 && today == 0) return '0% vs yesterday';
    if (yesterday == 0) return '↗ 100% vs yesterday';
    final pct = ((today - yesterday) / yesterday) * 100;
    final arrow = pct >= 0 ? '↗' : '↘';
    return '$arrow ${pct.abs().toStringAsFixed(1)}% vs yesterday';
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
    this.footnote,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final String? footnote;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (footnote != null) ...[
          const SizedBox(height: 3),
          Text(
            footnote!,
            style: const TextStyle(
              color: Color(0xFF99F6E4),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    );
  }
}

class _OverviewStats extends StatelessWidget {
  const _OverviewStats({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final stats = [
      _StatSpec(
        icon: Icons.layers_rounded,
        label: 'Stock',
        value: _formatQuantity(summary.totalStock),
        subtext: '${summary.lowStock.length} low',
        subtextColor: const Color(0xFFEF4444),
        color: colors.secondary,
      ),
      _StatSpec(
        icon: Icons.people_outline_rounded,
        label: 'Clients',
        value: '${summary.customerCount}',
        subtext: '${summary.customerDueCount} with dues',
        color: const Color(0xFF8B6F47),
      ),
      _StatSpec(
        icon: Icons.error_outline_rounded,
        label: 'Dues',
        value: money(summary.totalDue),
        subtext: '${summary.customerDueCount} clients',
        color: const Color(0xFFEF4444),
      ),
    ];
    return Row(
      children: [
        for (var index = 0; index < stats.length; index++) ...[
          Expanded(child: _StatCard(spec: stats[index])),
          if (index != stats.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _StatSpec {
  const _StatSpec({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtext,
    required this.color,
    this.subtextColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final String subtext;
  final Color color;
  final Color? subtextColor;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.spec});

  final _StatSpec spec;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 118,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFECE7DF)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: spec.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(spec.icon, color: spec.color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  spec.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            spec.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 19,
              color: colors.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            spec.subtext,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: spec.subtextColor ?? colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentSalesCard extends StatelessWidget {
  const _RecentSalesCard({required this.sales});

  final List<RecentSaleSummary> sales;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        children: [
          _SectionHeader(
            title: 'Recent Sales',
            action: 'See all',
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SalesHistoryScreen()),
            ),
          ),
          const SizedBox(height: 14),
          if (sales.isEmpty)
            const _InlineEmpty(message: 'No sales yet')
          else
            for (var index = 0; index < sales.length; index++) ...[
              if (index != 0)
                const Divider(height: 18, color: Color(0xFFF0ECE6)),
              _RecentSaleRow(sale: sales[index]),
            ],
        ],
      ),
    );
  }
}

class _RecentSaleRow extends StatelessWidget {
  const _RecentSaleRow({required this.sale});

  final RecentSaleSummary sale;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final paid = sale.isPaid;
    final statusColor = paid
        ? const Color(0xFF047857)
        : const Color(0xFF8B6F47);
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: paid ? const Color(0xFFDDFBF2) : const Color(0xFFF3F0EA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            paid ? Icons.done_all_rounded : Icons.schedule_rounded,
            color: statusColor,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sale.customerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${sale.invoiceNo} • ${sale.itemCount} items • ${_relativeTime(sale.createdAt)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              money(sale.amount),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              paid ? 'Paid' : 'Due',
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LowStockAlert extends StatelessWidget {
  const _LowStockAlert({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final visible = products.take(4).toList();
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Low Stock Alert',
            action: 'View all',
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LowStockProductsScreen(products: products),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (visible.isEmpty)
            const _InlineEmpty(message: 'No low stock products right now')
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  for (var index = 0; index < visible.length; index++) ...[
                    if (index != 0) const SizedBox(width: 10),
                    _LowStockProductCard(product: visible[index]),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LowStockProductCard extends StatelessWidget {
  const _LowStockProductCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 148,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFBF8),
        border: Border.all(color: const Color(0xFFECE7DF)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                '${product.stockQty} left',
                style: const TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            product.nameEn,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.onSurface,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'min ${product.lowStockAlert}',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFECE7DF)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (action != null)
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onAction,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: Text(
                action!,
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFBF8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: colors.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _formatQuantity(num value) {
  return (value is double ? value.toInt() : value).toString();
}

String _relativeTime(DateTime value) {
  final diff = DateTime.now().difference(value);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) {
    return diff.inHours == 1 ? '1 hour ago' : '${diff.inHours} hours ago';
  }
  return diff.inDays == 1 ? '1 day ago' : '${diff.inDays} days ago';
}
