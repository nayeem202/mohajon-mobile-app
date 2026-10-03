import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/product.dart';
import '../../../core/models/sale.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/widgets/insight_widgets.dart';
import '../../customers/providers/customer_providers.dart';
import '../../expenses/providers/expense_providers.dart';
import '../../products/providers/product_providers.dart';
import '../services/business_coach_service.dart';
import 'business_coach_screen.dart';
import 'business_guardian_screen.dart';
import 'cashflow_radar_screen.dart';

/// One decision hub for the three business intelligence tools.
///
/// Keeping these tools together makes the More menu easier to scan while the
/// individual screens remain focused and independently refreshable.
class BusinessHealthScreen extends ConsumerWidget {
  const BusinessHealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sales = ref.watch(salesStreamProvider).value ?? const <Sale>[];
    final products = ref.watch(productsProvider).value ?? const <Product>[];
    final customers = ref.watch(customersProvider).value ?? const <Customer>[];
    final payments = ref.watch(paymentsStreamProvider).value ?? const <Payment>[];
    final expenses = ref.watch(expensesProvider).value ?? const [];
    final insights = businessCoachService.generate(
      sales: sales,
      products: products,
      customers: customers,
      payments: payments,
      expenses: expenses,
    );
    final activeProducts = products.where((item) => !item.isDeleted);
    final lowStock = activeProducts.where((item) => item.isLowStock).length;
    final due = sales.where((item) => !item.isDeleted).fold<double>(
          0,
          (sum, sale) => sum + sale.dueAmount,
        ) -
        payments
            .where((item) => !item.isDeleted && item.saleId == null)
            .fold<double>(0, (sum, payment) => sum + payment.amount);
    final urgent = insights.where((item) => item.priority >= 90).length;
    final score = (100 - urgent * 15 - lowStock * 4 - (due / 1000).clamp(0, 25))
        .round()
        .clamp(0, 100);
    final accent = score >= 75
        ? MohajonWarm.green
        : score >= 50
            ? MohajonWarm.orange
            : MohajonWarm.red;
    return PremiumInsightPage(
      title: l10n.t('businessHealth'),
      subtitle: l10n.t('businessHealthSubtitle'),
      icon: Icons.monitor_heart_rounded,
      children: [
        const SizedBox(height: 18),
        InsightHeroCard(
          icon: Icons.monitor_heart_rounded,
          accent: MohajonWarm.goldText,
          title: l10n.t('businessHealthBrief'),
          body: score >= 75
              ? l10n.t('businessHealthHealthy')
              : l10n.t('businessHealthNeedsAttention'),
          trailingLabel: l10n.t('businessHealthTools'),
          trailingValue: '$score',
          badge: l10n.t('businessHealthScore'),
          badgeAccent: accent,
        ),
        const SizedBox(height: 14),
        InsightMetricGrid(
          tiles: [
            InsightMetricTile(
              label: l10n.t('businessHealthDueRisk'),
              value: '৳${due.clamp(0, double.infinity).toStringAsFixed(0)}',
              icon: Icons.account_balance_wallet_rounded,
              accent: due > 0 ? MohajonWarm.orange : MohajonWarm.green,
            ),
            InsightMetricTile(
              label: l10n.t('businessHealthLowStock'),
              value: '$lowStock',
              icon: Icons.inventory_2_rounded,
              accent: lowStock > 0 ? MohajonWarm.orange : MohajonWarm.green,
            ),
            InsightMetricTile(
              label: l10n.t('businessHealthInsights'),
              value: '${insights.length}',
              icon: Icons.lightbulb_rounded,
              accent: urgent > 0 ? MohajonWarm.red : MohajonWarm.primary,
            ),
          ],
        ),
        if (insights.isNotEmpty) ...[
          const SizedBox(height: 14),
          InsightSectionTitle(
            title: l10n.t('businessHealthTopActions'),
            icon: Icons.bolt_rounded,
            trailing: InsightBadge(label: '${insights.length}', accent: accent),
          ),
          for (final insight in insights.take(3)) ...[
            InsightRowTile(
              icon: Icons.lightbulb_circle_rounded,
              accent: insight.priority >= 90 ? MohajonWarm.red : MohajonWarm.orange,
              title: insight.titleEn,
              body: insight.bodyEn,
              trailing: insight.amount == null ? null : Text('৳${insight.amount!.toStringAsFixed(0)}'),
            ),
            const SizedBox(height: 8),
          ],
        ],
        const SizedBox(height: 8),
        const SizedBox(height: 16),
        _HealthToolCard(
          icon: Icons.lightbulb_circle_rounded,
          accent: MohajonWarm.goldText,
          title: l10n.t('featureBusinessCoach'),
          description: l10n.t('featureBusinessCoachSubtitle'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BusinessCoachScreen()),
          ),
        ),
        _HealthToolCard(
          icon: Icons.shield_rounded,
          accent: MohajonWarm.red,
          title: l10n.t('featureBusinessGuardian'),
          description: l10n.t('featureBusinessGuardianSubtitle'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BusinessGuardianScreen()),
          ),
        ),
        _HealthToolCard(
          icon: Icons.radar_rounded,
          accent: MohajonWarm.green,
          title: l10n.t('featureCashflowRadar'),
          description: l10n.t('featureCashflowRadarSubtitle'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CashflowRadarScreen()),
          ),
        ),
      ],
    );
  }
}

class _HealthToolCard extends StatelessWidget {
  const _HealthToolCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accent, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: MohajonWarm.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: MohajonWarm.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 15, color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
