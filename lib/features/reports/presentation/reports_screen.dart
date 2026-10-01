import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
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
import 'operational_report_screen.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  List<ReportItem> _allItems(AppLocalizations l10n) {
    return [
    ReportItem(
      id: 'cash_closing',
      icon: Icons.point_of_sale_rounded,
      title: l10n.t('reportCashClosing'),
      description: l10n.t('cashClosingReportDesc'),
      startColor: Color(0xFFB45309),
      endColor: Color(0xFFFBBF24),
    ),
    ReportItem(
      id: 'purchase_supplier',
      icon: Icons.local_shipping_rounded,
      title: l10n.t('reportPurchaseSupplier'),
      description: l10n.t('purchaseSupplierReportDesc'),
      startColor: Color(0xFF7C3AED),
      endColor: Color(0xFFC4B5FD),
    ),
    ReportItem(
      id: 'stock_movement',
      icon: Icons.swap_vert_rounded,
      title: l10n.t('reportStockMovement'),
      description: l10n.t('stockMovementReportDesc'),
      startColor: Color(0xFF2563EB),
      endColor: Color(0xFF93C5FD),
    ),
    ReportItem(
      id: 'customer_credit',
      icon: Icons.account_balance_wallet_rounded,
      title: l10n.t('reportCustomerCredit'),
      description: l10n.t('customerCreditReportDesc'),
      startColor: Color(0xFFDC2626),
      endColor: Color(0xFFFCA5A5),
    ),
    ReportItem(
      id: 'sales_profit',
      icon: Icons.insights_rounded,
      title: l10n.t('reportSalesProfit'),
      description: l10n.t('salesProfitReportDesc'),
      startColor: Color(0xFF059669),
      endColor: Color(0xFF6EE7B7),
    ),
    ReportItem(
      id: 'audit_activity',
      icon: Icons.fact_check_rounded,
      title: l10n.t('reportAuditActivity'),
      description: l10n.t('auditActivityReportDesc'),
      startColor: Color(0xFF9333EA),
      endColor: Color(0xFFD8B4FE),
    ),
    ReportItem(
      id: 'sales_summary',
      icon: Icons.bar_chart_rounded,
      title: l10n.t('reportSalesSummary'),
      description: l10n.t('salesSummaryDesc'),
      startColor: Color(0xFFD4930D),
      endColor: Color(0xFFF5B731),
    ),
    ReportItem(
      id: 'customer_ledger',
      icon: Icons.receipt_long_rounded,
      title: l10n.t('reportCustomerLedger'),
      description: l10n.t('customerLedgerDesc'),
      startColor: Color(0xFF0D9488),
      endColor: Color(0xFF2DD4BF),
    ),
    ReportItem(
      id: 'inventory_report',
      icon: Icons.inventory_2_rounded,
      title: l10n.t('reportInventory'),
      description: l10n.t('inventoryReportDesc'),
      startColor: Color(0xFF6366F1),
      endColor: Color(0xFFA5B4FC),
    ),
    ReportItem(
      id: 'expense_report',
      icon: Icons.payments_rounded,
      title: l10n.t('reportExpense'),
      description: l10n.t('expenseReportDesc'),
      startColor: Color(0xFFE11D48),
      endColor: Color(0xFFFDA4AF),
    ),
    ReportItem(
      id: 'profit_loss',
      icon: Icons.trending_up_rounded,
      title: l10n.t('reportProfitLoss'),
      description: l10n.t('profitLossDesc'),
      startColor: Color(0xFF059669),
      endColor: Color(0xFF6EE7B7),
    ),
    ReportItem(
      id: 'product_sales',
      icon: Icons.shopping_bag_rounded,
      title: l10n.t('reportProductSales'),
      description: l10n.t('productSalesDesc'),
      startColor: Color(0xFFD97706),
      endColor: Color(0xFFFCD34D),
    ),
    ReportItem(
      id: 'daily_transactions',
      icon: Icons.receipt_rounded,
      title: l10n.t('reportDailyTransactions'),
      description: l10n.t('dailyTransactionsDesc'),
      startColor: Color(0xFF2563EB),
      endColor: Color(0xFF93C5FD),
    ),
    ReportItem(
      id: 'payment_methods',
      icon: Icons.payment_rounded,
      title: l10n.t('reportPaymentMethods'),
      description: l10n.t('paymentMethodsDesc'),
      startColor: Color(0xFF9333EA),
      endColor: Color(0xFFD8B4FE),
    ),
    ReportItem(
      id: 'due_payments',
      icon: Icons.warning_amber_rounded,
      title: l10n.t('reportDuePayments'),
      description: l10n.t('duePaymentsDesc'),
      startColor: Color(0xFFDC2626),
      endColor: Color(0xFFFCA5A5),
    ),
    ReportItem(
      id: 'vat_report',
      icon: Icons.calculate_rounded,
      title: l10n.t('reportVat'),
      description: l10n.t('vatReportDesc'),
      startColor: Color(0xFF0891B2),
      endColor: Color(0xFF67E8F9),
    ),
    ReportItem(
      id: 'staff_performance',
      icon: Icons.people_rounded,
      title: l10n.t('reportStaffPerformance'),
      description: l10n.t('staffPerformanceDesc'),
      startColor: Color(0xFF64748B),
      endColor: Color(0xFFCBD5E1),
      available: true,
    ),
  ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
          title: Text(
            l10n.t('reports'),
            style: const TextStyle(
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
                _SectionLabel(label: l10n.t('allReports')),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.32,
                  children: [
                    for (final item in _allItems(l10n))
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
    final l10n = AppLocalizations.of(context);
    if (!item.available) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.tP('comingSoon', {'title': item.title})),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
      return;
    }

    final Widget? screen = switch (item.id) {
      'sales_summary' => const SalesSummaryScreen(),
      'customer_ledger' => const CustomerLedgerScreen(),
      'inventory_report' => const InventoryReportScreen(),
      'expense_report' => const ExpenseReportScreen(),
      'profit_loss' => const ProfitLossScreen(),
      'product_sales' => const ProductSalesScreen(),
      'daily_transactions' => const DailyTransactionsScreen(),
      'payment_methods' => const PaymentMethodsScreen(),
      'due_payments' => const DuePaymentsScreen(),
      'vat_report' => const VatReportScreen(),
      'cash_closing' => const OperationalReportScreen(type: OperationalReportType.cashClosing),
      'purchase_supplier' => const OperationalReportScreen(type: OperationalReportType.purchaseSupplier),
      'stock_movement' => const OperationalReportScreen(type: OperationalReportType.stockMovement),
      'customer_credit' => const OperationalReportScreen(type: OperationalReportType.customerCredit),
      'sales_profit' => const OperationalReportScreen(type: OperationalReportType.salesProfit),
      'staff_performance' => const OperationalReportScreen(type: OperationalReportType.staffPerformance),
      'audit_activity' => const OperationalReportScreen(type: OperationalReportType.auditActivity),
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
    final l10n = AppLocalizations.of(context);
    final margin = totalSales > 0
        ? (totalProfit / totalSales).clamp(0.0, 1.0)
        : 0.0;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MohajonWarm.card, Color(0xFFFFF8EB), Color(0xFFFFFBEF)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MohajonWarm.goldBorder),
        boxShadow: [
          BoxShadow(
            color: MohajonWarm.primary.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: MohajonWarm.ink.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MohajonWarm.primary.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -20,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MohajonWarm.primarySoft.withValues(alpha: 0.08),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [MohajonWarm.primary, MohajonWarm.primarySoft],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: MohajonWarm.primary.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    l10n.t('reportCenter').toUpperCase(),
                    style: const TextStyle(
                      color: MohajonWarm.ink,
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
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x5522C55E),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.t('live'),
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
                _HeroRing(
                  value: margin,
                  amount: _compact(totalSales),
                  pct: (margin * 100).round(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.t('businessAtGlance'),
                        style: const TextStyle(
                          color: MohajonWarm.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.t('reportsHeroSub'),
                        style: TextStyle(
                          color: MohajonWarm.muted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _HeroChip(
                        label: l10n.t('profit'),
                        value: _compact(totalProfit),
                        color: const Color(0xFF059669),
                      ),
                      const SizedBox(height: 8),
                      _HeroChip(
                        label: l10n.t('expenses'),
                        value: _compact(totalExpenses),
                        color: const Color(0xFFD97706),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],    // Column children
        ),      // Column
      ),        // Padding
        ],      // Stack children
      ),        // Stack
    );
  }
}

class _HeroRing extends StatelessWidget {
  const _HeroRing({
    required this.value,
    required this.amount,
    required this.pct,
  });

  final double value;
  final String amount;
  final int pct;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: 124,
      height: 124,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 124,
            height: 124,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: MohajonWarm.tintYellow,
              boxShadow: [
                BoxShadow(
                  color: MohajonWarm.primary.withValues(alpha: 0.2),
                  blurRadius: 22,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          SizedBox(
            width: 124,
            height: 124,
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 11,
              strokeCap: StrokeCap.round,
              color: MohajonWarm.primary,
              backgroundColor: MohajonWarm.primary.withValues(alpha: 0.12),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                amount,
                style: TextStyle(
                  color: MohajonWarm.ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                l10n.t('totalSales'),
                style: TextStyle(
                  color: MohajonWarm.muted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [MohajonWarm.primary, MohajonWarm.primarySoft],
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l10n.tP('margin', {'pct': '$pct'}),
                  style: TextStyle(
                    color: MohajonWarm.ink,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                  ),
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
  const _HeroChip({
    required this.label,
    required this.value,
    this.color = MohajonWarm.primary,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(
              color: color,
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
              color: color,
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
    final l10n = AppLocalizations.of(context);
    final available = item.available;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [MohajonWarm.card, Color(0xFFFFFBEF)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: MohajonWarm.goldBorder),
            boxShadow: [
              BoxShadow(
                color: MohajonWarm.ink.withValues(alpha: 0.07),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -22,
                right: -22,
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item.startColor.withValues(alpha: available ? 0.09 : 0.05),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: available
                                ? LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [item.startColor, item.endColor],
                                  )
                                : null,
                            color: available ? null : MohajonWarm.tintYellow,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: available
                                ? [
                                    BoxShadow(
                                      color: item.startColor.withValues(alpha: 0.32),
                                      blurRadius: 12,
                                      offset: const Offset(0, 5),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            item.icon,
                            color: available ? Colors.white : item.startColor,
                            size: 23,
                          ),
                        ),
                        const Spacer(),
                        if (!available)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: MohajonWarm.tintYellow,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              l10n.t('soon'),
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                                color: MohajonWarm.goldText,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: MohajonWarm.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
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
                    if (available)
                      Row(
                        children: [
                          Text(
                            l10n.t('openReport'),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: MohajonWarm.goldText,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 13,
                            color: MohajonWarm.goldText,
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
