import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/models/product.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../products/presentation/product_form_screen.dart';
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
    final theme = Theme.of(context);
    final homeTheme = theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        primary: const Color(0xFFFFC800),
        onPrimary: Colors.white,
        secondary: const Color(0xFF2F3028),
        onSecondary: Colors.white,
        tertiary: const Color(0xFFFFD83D),
        onTertiary: Colors.white,
        surface: const Color(0xFFFFFCF0),
        onSurface: const Color(0xFF2F3028),
        surfaceContainerHighest: const Color(0xFFFFF0A6),
        onSurfaceVariant: const Color(0xFF77735F),
        outline: const Color(0xFFF0DF9A),
        outlineVariant: const Color(0xFFFFF0A6),
      ),
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: theme.appBarTheme.copyWith(
        foregroundColor: const Color(0xFF2F3028),
      ),
    );

    return Theme(
      data: homeTheme,
      child: LoadingOverlay(
        loading: sync.phase == SyncPhase.syncing,
        label: 'Syncing data...',
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.28, 0.47, 1.0],
                colors: [
                  Color(0xFFFFC800),
                  Color(0xFFFFD83D),
                  Color(0xFFFFF0A6),
                  Color(0xFFFFFCF0),
                ],
              ),
            ),
            child: SafeArea(
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
                      data: summary.dayWiseSales
                          .map(
                            (d) => WeeklySalesData(
                              dayLabel: d.label,
                              fullDayName: DateFormat('EEEE').format(d.date),
                              sales: d.sales,
                            ),
                          )
                          .toList(),
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
    final name = profile?.ownerName ?? '';
    final imagePath = profile?.imagePath;

    return IconTheme(
      data: const IconThemeData(color: Color(0xFF2F3028)),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFC800), Color(0xFFFFE36E)],
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFC800).withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: Color(0xFF2F3028),
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mohajon',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2F3028),
                  ),
                ),
                Text(
                  'Smart shop management',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF77735F),
                  ),
                ),
              ],
            ),
          ),
          const NotificationBell(),
          const SizedBox(width: 14),
          AppAvatar(
            name: name,
            imagePath: imagePath,
            onTap: onAvatarTap,
            radius: 17,
            backgroundColor: Color(0xFFFFFDF7),
            textColor: Color(0xFF2F3028),
          ),
        ],
      ),
    );
  }
}

class _GreetingPanel extends StatelessWidget {
  const _GreetingPanel({required this.summary, required this.name});

  final DashboardSummary summary;
  final String name;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEEE, MMMM d, y').format(DateTime.now());
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [
            Color(0xFFFFFEF8),
            Color(0xFFFFF9E9),
            Color(0xFFFFF0C2),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB58A24).withValues(alpha: 0.18),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -54,
            top: -76,
            child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFC800).withValues(alpha: 0.10),
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: -110,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFFC800).withValues(alpha: 0.18),
                  width: 28,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        date,
                        style: const TextStyle(
                          color: Color(0xFF77735F),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFC800).withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: const Color(
                            0xFFFFC800,
                          ).withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.wb_sunny_rounded,
                            color: Color(0xFF5D4A00),
                            size: 14,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'OPEN TODAY',
                            style: TextStyle(
                              color: Color(0xFF5D4A00),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Good day, $name!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF2F3028),
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Here is your shop at a glance.',
                  style: const TextStyle(
                    color: Color(0xFF77735F),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC800).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFEADFAE)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _HeroMetric(
                          label: "Today's Sales",
                          value: money(summary.todaySales),
                          footnote: _salesChangeFootnote(summary),
                          foregroundColor: const Color(0xFF2F3028),
                          labelColor: const Color(0xFF77735F),
                          footnoteColor: const Color(0xFF8A6500),
                        ),
                      ),
                      Container(
                        height: 42,
                        width: 1,
                        color: const Color(0xFFEADFAE),
                      ),
                      Expanded(
                        child: _HeroMetric(
                          label: 'Transactions',
                          value: '${summary.todayTransactionCount}',
                          alignEnd: true,
                          foregroundColor: const Color(0xFF2F3028),
                          labelColor: const Color(0xFF77735F),
                        ),
                      ),
                    ],
                  ),
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
    this.foregroundColor = Colors.white,
    this.labelColor,
    this.footnoteColor,
  });

  final String label;
  final String value;
  final String? footnote;
  final bool alignEnd;
  final Color foregroundColor;
  final Color? labelColor;
  final Color? footnoteColor;

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
            color: labelColor ?? foregroundColor.withValues(alpha: 0.9),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: foregroundColor,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (footnote != null) ...[
          const SizedBox(height: 3),
          Text(
            footnote!,
            style: TextStyle(
              color: footnoteColor ?? const Color(0xFF8A6500),
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
    final totalDue = summary.totalDue;
    final isAdvance = totalDue < 0;
    final stats = [
      _StatSpec(
        icon: Icons.inventory_2_rounded,
        label: 'Stock',
        value: _formatQuantity(summary.totalStock),
        subtext: '${summary.lowStock.length} low',
        color: const Color(0xFF5D5B45),
        background: const Color(0xFFFFF4BF),
      ),
      _StatSpec(
        icon: Icons.people_alt_rounded,
        label: 'Clients',
        value: '${summary.customerCount}',
        subtext: '${summary.customerDueCount} with dues',
        color: const Color(0xFFFFA800),
        background: const Color(0xFFFFF8DD),
      ),
      _StatSpec(
        icon: isAdvance
            ? Icons.account_balance_wallet_rounded
            : Icons.payments_rounded,
        label: isAdvance ? 'Advance' : 'Dues',
        value: money(totalDue.abs()),
        subtext: isAdvance
            ? 'Received in advance'
            : '${summary.customerDueCount} clients',
        color: isAdvance ? const Color(0xFF047857) : const Color(0xFFEF4444),
        background: isAdvance
            ? const Color(0xFFEFF7E5)
            : const Color(0xFFFFF0E2),
      ),
    ];
    return Row(
      children: [
        for (var index = 0; index < stats.length; index++) ...[
          Expanded(child: _StatCard(spec: stats[index])),
          if (index != stats.length - 1) const SizedBox(width: 12),
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
    required this.background,
  });

  final IconData icon;
  final String label;
  final String value;
  final String subtext;
  final Color color;
  final Color background;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.spec});

  final _StatSpec spec;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 130,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [spec.background, const Color(0xFFFFFDF7)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEADFAE)),
        boxShadow: [
          BoxShadow(
            color: spec.color.withValues(alpha: 0.09),
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
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: spec.color.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(spec.icon, color: spec.color, size: 16),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: spec.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    spec.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: spec.color,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              spec.value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 20,
                color: colors.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            spec.subtext,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: colors.onSurfaceVariant,
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
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFFFF8E6)],
        ),
        border: Border.all(color: const Color(0xFFEADFAE)),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B5A2A).withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFC800), Color(0xFFFFD83D)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0A6),
                  shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFF2F3028),
                    size: 17,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Low Stock Alert',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFF2F3028),
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${products.length} items',
                    style: const TextStyle(
                      color: Color(0xFF2F3028),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          LowStockProductsScreen(products: products),
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                    child: Row(
                      children: [
                        Text(
                          'View all',
                          style: TextStyle(
                            color: Color(0xFF2F3028),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFF2F3028),
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            child: visible.isEmpty
                ? const _InlineEmpty(message: 'No low stock products right now')
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        for (
                          var index = 0;
                          index < visible.length;
                          index++
                        ) ...[
                          if (index != 0) const SizedBox(width: 10),
                          _LowStockProductCard(product: visible[index]),
                        ],
                      ],
                    ),
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
    final isOut = product.stockQty <= 0;
    final statusColor = isOut ? MohajonWarm.red : MohajonWarm.orange;
    final level = (product.stockQty / (product.lowStockAlert * 2))
        .clamp(0.0, 1.0)
        .toDouble();
    // Match the New Sale (POS) product card width: (screenWidth - 76) / 3,
    // where 76 = 2*16 (outer pad) + 2*12 (grid pad) + 2*10 (spacing).
    final cardWidth =
        ((MediaQuery.of(context).size.width - 76) / 3).clamp(96.0, 140.0);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductFormScreen(product: product),
          ),
        ),
        child: Container(
          width: cardWidth,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: MohajonWarm.goldBorder),
            boxShadow: [
              BoxShadow(
                color: statusColor.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(17),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: product.imagePath != null
                          ? AppImage.file(
                              File(product.imagePath!),
                              width: double.infinity,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _fallbackImage(),
                            )
                          : _fallbackImage(),
                    ),
                  ),
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(17),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              statusColor.withValues(alpha: 0.16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 7,
                    left: 7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isOut
                                ? Icons.block_rounded
                                : Icons.warning_amber_rounded,
                            size: 11,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            isOut ? 'Out' : 'Low',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.nameEn,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MohajonWarm.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isOut ? '0 left' : '${product.stockQty} left',
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Min ${product.lowStockAlert}',
                          style: const TextStyle(
                            color: MohajonWarm.muted,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        height: 5,
                        color: MohajonWarm.tintYellow,
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: level,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [MohajonWarm.orange, statusColor],
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
        ),
      ),
    );
  }

  Widget _fallbackImage() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF0C2), Color(0xFFFCE3B4)],
        ),
      ),
      child: Center(
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE98300).withValues(alpha: 0.18),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.inventory_2_rounded,
            color: Color(0xFFE98300),
            size: 18,
          ),
        ),
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
        color: const Color(0xFFFFFDF7),
        border: Border.all(color: const Color(0xFFEADFAE)),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B5A2A).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
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
        color: const Color(0xFFFFFDF7),
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
