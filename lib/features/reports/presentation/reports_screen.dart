import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/models/sale.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';
import '../models/report_item.dart';
import 'customer_ledger_screen.dart';
import 'daily_transactions_screen.dart';
import 'due_payments_screen.dart';
import 'expense_report_screen.dart';
import 'inventory_report_screen.dart';
import 'payment_methods_screen.dart';
import 'product_sales_screen.dart';
import 'profit_loss_screen.dart';
import 'sales_summary_screen.dart';
import 'vat_report_screen.dart';

const _warmStart = MohajonWarm.primary;
const _warmEnd = MohajonWarm.primarySoft;

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
      startColor: _warmStart,
      endColor: _warmEnd,
    ),
    ReportItem(
      icon: Icons.receipt_long_rounded,
      title: 'Customer Ledger',
      description: 'Customer-wise due & payment history',
      startColor: _warmStart,
      endColor: _warmEnd,
    ),
    ReportItem(
      icon: Icons.inventory_2_rounded,
      title: 'Inventory Report',
      description: 'Stock levels, low stock & valuation',
      startColor: _warmStart,
      endColor: _warmEnd,
    ),
    ReportItem(
      icon: Icons.payments_rounded,
      title: 'Expense Report',
      description: 'Date range expenses with PDF & XLSX export',
      startColor: _warmStart,
      endColor: _warmEnd,
    ),
    ReportItem(
      icon: Icons.trending_up_rounded,
      title: 'Profit & Loss',
      description: 'Revenue, cost & net profit summary',
      startColor: _warmStart,
      endColor: _warmEnd,
    ),
    ReportItem(
      icon: Icons.shopping_bag_rounded,
      title: 'Product-wise Sales',
      description: 'Quantity & revenue per product',
      startColor: _warmStart,
      endColor: _warmEnd,
    ),
    ReportItem(
      icon: Icons.receipt_rounded,
      title: 'Daily Transactions',
      description: 'All transactions recorded per day',
      startColor: _warmStart,
      endColor: _warmEnd,
    ),
    ReportItem(
      icon: Icons.payment_rounded,
      title: 'Payment Methods',
      description: 'Cash, bKash, Nagad & card breakdown',
      startColor: _warmStart,
      endColor: _warmEnd,
    ),
    ReportItem(
      icon: Icons.warning_amber_rounded,
      title: 'Due Payments',
      description: 'Overdue and pending payment list',
      startColor: _warmStart,
      endColor: _warmEnd,
    ),
    ReportItem(
      icon: Icons.calculate_rounded,
      title: 'VAT Report',
      description: 'VAT collected summaries',
      startColor: _warmStart,
      endColor: _warmEnd,
    ),
    ReportItem(
      icon: Icons.people_rounded,
      title: 'Staff Performance',
      description: 'Sales & transactions by staff',
      startColor: _warmStart,
      endColor: _warmEnd,
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

    return Theme(
      data: MohajonWarm.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Reports',
            style: TextStyle(
              color: MohajonWarm.ink,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          backgroundColor: MohajonWarm.primary,
          foregroundColor: MohajonWarm.ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: MohajonWarm.primary,
            statusBarIconBrightness: Brightness.dark,
          ),
          actions: const [
            NotificationBell(),
            SizedBox(width: 6),
            ShopAvatar(),
          ],
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: MohajonWarm.pageGradient),
          child: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: [
                _StatsHero(
                  totalSales: totalSales,
                  totalProfit: totalProfit,
                  totalExpenses: totalExpenses,
                ),
                const SizedBox(height: 22),
                _SectionLabel(label: 'All Reports'),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.42,
                  children: [
                    for (final item in _allItems)
                      _ReportGridCard(
                        item: item,
                        onTap: () => _open(item, context),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
      'Profit & Loss' => const ProfitLossScreen(),
      'Product-wise Sales' => const ProductSalesScreen(),
      'Daily Transactions' => const DailyTransactionsScreen(),
      'Payment Methods' => const PaymentMethodsScreen(),
      'Due Payments' => const DuePaymentsScreen(),
      'VAT Report' => const VatReportScreen(),
      _ => null,
    };
    if (screen == null) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

String _compact(double value) {
  if (value >= 10000000) return '${(value / 10000000).toStringAsFixed(1)} Cr';
  if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)} L';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
  return value.toStringAsFixed(0);
}

// ---------------------------------------------------------------------------
// Hero
// ---------------------------------------------------------------------------

class _StatsHero extends StatelessWidget {
  const _StatsHero({
    required this.totalSales,
    required this.totalProfit,
    required this.totalExpenses,
  });

  final double totalSales;
  final double totalProfit;
  final double totalExpenses;

  @override
  Widget build(BuildContext context) {
    final margin = totalSales > 0
        ? (totalProfit / totalSales).clamp(0.0, 1.0)
        : 0.0;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: MohajonWarm.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MohajonWarm.goldBorder),
        boxShadow: [
          BoxShadow(
            color: MohajonWarm.ink.withValues(alpha: 0.07),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: MohajonWarm.tintYellow,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'REPORT CENTER',
                    style: TextStyle(
                      color: MohajonWarm.goldText,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Live',
                      style: TextStyle(
                        color: MohajonWarm.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _HeroRing(value: margin, amount: _compact(totalSales)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Business at a glance',
                        style: TextStyle(
                          color: MohajonWarm.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Live insights from your sales, expenses & inventory.',
                        style: TextStyle(
                          color: MohajonWarm.muted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _HeroChip(label: 'Profit', value: _compact(totalProfit)),
                      const SizedBox(height: 8),
                      _HeroChip(label: 'Expenses', value: _compact(totalExpenses)),
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

class _HeroRing extends StatelessWidget {
  const _HeroRing({required this.value, required this.amount});

  final double value;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 116,
      height: 116,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 116,
            height: 116,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: MohajonWarm.tintYellow,
            ),
          ),
          SizedBox(
            width: 116,
            height: 116,
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 12,
              color: MohajonWarm.primary,
              backgroundColor: Colors.transparent,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                amount,
                style: const TextStyle(
                  color: MohajonWarm.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Total Sales',
                style: TextStyle(
                  color: MohajonWarm.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: MohajonWarm.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MohajonWarm.goldBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(
              color: MohajonWarm.primary,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: MohajonWarm.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: MohajonWarm.ink,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grid
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [MohajonWarm.primary, MohajonWarm.primarySoft],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.grid_view_rounded, size: 15, color: MohajonWarm.ink),
        ),
        const SizedBox(width: 9),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.9,
            color: MohajonWarm.ink.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

class _ReportGridCard extends StatelessWidget {
  const _ReportGridCard({required this.item, required this.onTap});

  final ReportItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final available = item.available;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: MohajonWarm.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: MohajonWarm.goldBorder),
            boxShadow: [
              BoxShadow(
                color: MohajonWarm.ink.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: available
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [_warmStart, _warmEnd],
                              )
                            : null,
                        color: available ? null : MohajonWarm.tintYellow,
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: available
                            ? [
                                BoxShadow(
                                  color: _warmStart.withValues(alpha: 0.28),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        item.icon,
                        color: available ? Colors.white : _warmStart,
                        size: 21,
                      ),
                    ),
                    const Spacer(),
                    if (!available)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: MohajonWarm.tintYellow,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'SOON',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                            color: MohajonWarm.goldText,
                          ),
                        ),
                      )
                    else
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: MohajonWarm.goldText,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: MohajonWarm.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Expanded(
                  child: Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: MohajonWarm.muted,
                      fontWeight: FontWeight.w500,
                    ),
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
