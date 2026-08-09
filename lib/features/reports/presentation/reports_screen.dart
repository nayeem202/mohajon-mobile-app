import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/models/sale.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';
import '../models/report_item.dart';
import 'customer_ledger_screen.dart';
import 'expense_report_screen.dart';
import 'inventory_report_screen.dart';
import 'sales_summary_screen.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  static const List<ReportItem> _allItems = [
    ReportItem(
      icon: Icons.bar_chart_rounded,
      title: 'Sales Summary',
      description: 'Daily, weekly & monthly sales overview',
      startColor: Color(0xFFF97316),
      endColor: Color(0xFFFBBF24),
    ),
    ReportItem(
      icon: Icons.receipt_long_rounded,
      title: 'Customer Ledger',
      description: 'Customer-wise due & payment history',
      startColor: Color(0xFF2563EB),
      endColor: Color(0xFF60A5FA),
    ),
    ReportItem(
      icon: Icons.inventory_2_rounded,
      title: 'Inventory Report',
      description: 'Stock levels, low stock & valuation',
      startColor: Color(0xFF0F766E),
      endColor: Color(0xFF14B8A6),
    ),
    ReportItem(
      icon: Icons.payments_rounded,
      title: 'Expense Report',
      description: 'Date range expenses with PDF & XLSX export',
      startColor: Color(0xFFDC2626),
      endColor: Color(0xFFF87171),
    ),
    ReportItem(
      icon: Icons.trending_up_rounded,
      title: 'Profit & Loss',
      description: 'Revenue, cost & net profit summary',
      startColor: Color(0xFF059669),
      endColor: Color(0xFF34D399),
      available: false,
    ),
    ReportItem(
      icon: Icons.shopping_bag_rounded,
      title: 'Product-wise Sales',
      description: 'Quantity & revenue per product',
      startColor: Color(0xFFD97706),
      endColor: Color(0xFFFBBF24),
      available: false,
    ),
    ReportItem(
      icon: Icons.receipt_rounded,
      title: 'Daily Transactions',
      description: 'All transactions recorded per day',
      startColor: Color(0xFF0891B2),
      endColor: Color(0xFF22D3EE),
      available: false,
    ),
    ReportItem(
      icon: Icons.payment_rounded,
      title: 'Payment Methods',
      description: 'Cash, bKash, Nagad & card breakdown',
      startColor: Color(0xFF7C3AED),
      endColor: Color(0xFFA78BFA),
      available: false,
    ),
    ReportItem(
      icon: Icons.warning_amber_rounded,
      title: 'Due Payments',
      description: 'Overdue and pending payment list',
      startColor: Color(0xFFDC2626),
      endColor: Color(0xFFFB7185),
      available: false,
    ),
    ReportItem(
      icon: Icons.calculate_rounded,
      title: 'VAT Report',
      description: 'VAT collected summaries',
      startColor: Color(0xFF0891B2),
      endColor: Color(0xFF67E8F9),
      available: false,
    ),
    ReportItem(
      icon: Icons.people_rounded,
      title: 'Staff Performance',
      description: 'Sales & transactions by staff',
      startColor: Color(0xFF7C3AED),
      endColor: Color(0xFFC084FC),
      available: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(localDatabaseProvider);

    final sales = db.sales.values();
    final totalSales = sales.fold<double>(
      0,
      (sum, sale) => sum + sale.totalAmount,
    );
    final totalProfit = sales.fold<double>(0, (sum, sale) => sum + sale.profit);
    final totalExpenses = db.expenses.values().fold<double>(
      0,
      (sum, expense) => sum + expense.amount,
    );
    final weekBars = _buildWeekBars(sales);

    final featured = _allItems.where((item) => item.available).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          const NotificationBell(),
          const SizedBox(width: 6),
          const ShopAvatar(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          _StatsHero(
            totalSales: totalSales,
            totalProfit: totalProfit,
            totalExpenses: totalExpenses,
            weekBars: weekBars,
          ),
          const SizedBox(height: 22),
          _SectionHeader(
            label: 'Quick View',
            icon: Icons.bolt_rounded,
            tint: const Color(0xFFF97316),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 128,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: featured.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = featured[index];
                return _QuickViewCard(
                  item: item,
                  onTap: () => _open(item, context),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(
            label: 'Business Performance',
            icon: Icons.insights_rounded,
            tint: const Color(0xFF059669),
          ),
          const SizedBox(height: 12),
          ..._buildSection(context, _allItems, [4, 5, 6]),
          const SizedBox(height: 24),
          _SectionHeader(
            label: 'Finance & Payments',
            icon: Icons.account_balance_wallet_rounded,
            tint: const Color(0xFF7C3AED),
          ),
          const SizedBox(height: 12),
          ..._buildSection(context, _allItems, [7, 8, 9]),
          const SizedBox(height: 24),
          _SectionHeader(
            label: 'People',
            icon: Icons.people_alt_rounded,
            tint: const Color(0xFF2563EB),
          ),
          const SizedBox(height: 12),
          ..._buildSection(context, _allItems, [10]),
        ],
      ),
    );
  }

  List<Widget> _buildSection(
    BuildContext context,
    List<ReportItem> items,
    List<int> indexes,
  ) {
    return [
      for (var i = 0; i < indexes.length; i++)
        Padding(
          padding: EdgeInsets.only(bottom: i == indexes.length - 1 ? 0 : 10),
          child: _ReportTile(
            index: indexes[i],
            item: items[indexes[i]],
            onTap: () => _open(items[indexes[i]], context),
          ),
        ),
    ];
  }

  void _open(ReportItem item, BuildContext context) {
    if (!item.available) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('${item.title} is coming soon'),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
      return;
    }

    final Widget? screen = switch (item.title) {
      'Sales Summary' => const SalesSummaryScreen(),
      'Customer Ledger' => const CustomerLedgerScreen(),
      'Inventory Report' => const InventoryReportScreen(),
      'Expense Report' => const ExpenseReportScreen(),
      _ => null,
    };
    if (screen == null) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  static List<double> _buildWeekBars(List<Sale> sales) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final bars = List<double>.filled(7, 0);
    for (final sale in sales) {
      final day = DateTime(
        sale.createdAt.year,
        sale.createdAt.month,
        sale.createdAt.day,
      );
      final diff = today.difference(day).inDays;
      if (diff >= 0 && diff < 7) bars[6 - diff] += sale.totalAmount;
    }
    return bars;
  }
}

// ---------------------------------------------------------------------------
// Hero
// ---------------------------------------------------------------------------

class _StatsHero extends StatelessWidget {
  const _StatsHero({
    required this.totalSales,
    required this.totalProfit,
    required this.totalExpenses,
    required this.weekBars,
  });

  final double totalSales;
  final double totalProfit;
  final double totalExpenses;
  final List<double> weekBars;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1F1812), Color(0xFF3A2A1B)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1C1917).withValues(alpha: 0.25),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              top: -50,
              right: -40,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              left: -30,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF97316).withValues(alpha: 0.14),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF97316), Color(0xFFFBBF24)],
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'REPORT CENTER',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF34D399),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Live',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Business at a glance',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Live insights from your sales, expenses & inventory.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _HeroBigTile(
                          icon: Icons.payments_rounded,
                          label: 'Total Sales',
                          value: _compact(totalSales),
                          iconColor: const Color(0xFFFBBF24),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          children: [
                            _HeroSmallTile(
                              icon: Icons.trending_up_rounded,
                              label: 'Profit',
                              value: _compact(totalProfit),
                              iconColor: const Color(0xFF34D399),
                            ),
                            const SizedBox(height: 10),
                            _HeroSmallTile(
                              icon: Icons.shopping_bag_rounded,
                              label: 'Expenses',
                              value: _compact(totalExpenses),
                              iconColor: const Color(0xFFF87171),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _WeekChart(bars: weekBars),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _compact(double value) {
    if (value >= 10000000) {
      return '${(value / 10000000).toStringAsFixed(1)} Cr';
    }
    if (value >= 100000) {
      return '${(value / 100000).toStringAsFixed(1)} L';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toStringAsFixed(0);
  }
}

class _HeroBigTile extends StatelessWidget {
  const _HeroBigTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSmallTile extends StatelessWidget {
  const _HeroSmallTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 15),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.bars});

  final List<double> bars;

  @override
  Widget build(BuildContext context) {
    const dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final maxValue = bars.fold<double>(0, (max, v) => v > max ? v : max);
    final effectiveMax = maxValue > 0 ? maxValue : 1.0;
    final total = bars.fold<double>(0, (sum, v) => sum + v);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'This week',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            const Spacer(),
            Text(
              '৳ ${_compact(total)}',
              style: const TextStyle(
                color: Color(0xFFFBBF24),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 56,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final value = bars[i];
              final height = value > 0
                  ? (value / effectiveMax) * 48
                  : 5.0;
              final isToday = i == 6;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: double.infinity,
                        height: height.clamp(4, 48),
                        decoration: BoxDecoration(
                          gradient: isToday
                              ? const LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Color(0xFFF97316),
                                    Color(0xFFFBBF24),
                                  ],
                                )
                              : null,
                          color: isToday
                              ? null
                              : Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        dayLetters[i],
                        style: TextStyle(
                          color: i == 6
                              ? const Color(0xFFFBBF24)
                              : Colors.white.withValues(alpha: 0.4),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  static String _compact(double value) {
    if (value >= 10000000) return '${(value / 10000000).toStringAsFixed(1)} Cr';
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)} L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return value.toStringAsFixed(0);
  }
}

// ---------------------------------------------------------------------------
// Sections
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.icon,
    required this.tint,
  });

  final String label;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: tint),
        ),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }
}

class _QuickViewCard extends StatelessWidget {
  const _QuickViewCard({required this.item, required this.onTap});

  final ReportItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          width: 148,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [item.startColor, item.endColor],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: item.startColor.withValues(alpha: 0.32),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -24,
                top: -24,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(item.icon, color: Colors.white, size: 19),
                    ),
                    const Spacer(),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          'Open report',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ],
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
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({
    required this.index,
    required this.item,
    required this.onTap,
  });

  final int index;
  final ReportItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final available = item.available;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: available
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [item.startColor, item.endColor],
                          )
                        : null,
                    color: available
                        ? null
                        : item.startColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    item.icon,
                    color: available ? Colors.white : item.startColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: colors.onSurface,
                              ),
                            ),
                          ),
                          if (!available) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: item.startColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'SOON',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                  color: item.startColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: Color(0xFF98A2B3),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: available
                        ? item.startColor.withValues(alpha: 0.1)
                        : colors.outlineVariant.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    available
                        ? Icons.arrow_forward_rounded
                        : Icons.lock_outline_rounded,
                    size: 15,
                    color: available
                        ? item.startColor
                        : colors.onSurfaceVariant.withValues(alpha: 0.4),
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
