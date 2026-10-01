import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/product.dart';
import '../../../core/models/sale.dart';
import '../../../core/services/api_client.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/insight_widgets.dart';
import '../../customers/providers/customer_providers.dart';
import '../../expenses/providers/expense_providers.dart';
import '../../products/providers/product_providers.dart';
import '../services/business_coach_service.dart';

class BusinessCoachScreen extends ConsumerStatefulWidget {
  const BusinessCoachScreen({super.key});

  @override
  ConsumerState<BusinessCoachScreen> createState() => _BusinessCoachScreenState();
}

class _BusinessCoachScreenState extends ConsumerState<BusinessCoachScreen> {
  bool _syncing = true;
  int? _historyCount;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_syncCoachHistory);
  }

  Future<void> _syncCoachHistory() async {
    try {
      final api = ApiClient(ref.read(localDatabaseProvider));
      await api.post('/api/v1/business-coach/refresh', const {});
      if (mounted) setState(() => _historyCount = 1);
    } catch (_) {
      // Local calculations remain available when the backend is temporarily offline.
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
    final isBangla = Localizations.localeOf(context).languageCode == 'bn';
    final l10n = AppLocalizations.of(context);

    final urgentCount =
        insights.where((item) => item.priority >= 90).length;
    final cashAtRisk = insights.fold<double>(
      0,
      (sum, item) => sum + (item.amount ?? 0),
    );
    final accent = urgentCount > 0
        ? MohajonWarm.red
        : insights.isNotEmpty
            ? MohajonWarm.orange
            : MohajonWarm.green;

    return PremiumInsightPage(
      title: l10n.t('coachTitle'),
      subtitle: l10n.t('featureBusinessCoachSubtitle'),
      icon: Icons.auto_awesome_rounded,
      children: [
        const SizedBox(height: 18),
        InsightHeroCard(
          icon: Icons.auto_awesome_rounded,
          accent: accent,
          title: l10n.t('coachTodayBrief'),
          body: _syncing
              ? l10n.t('coachSyncing')
              : _historyCount != null
                  ? l10n.tP('coachHistorySaved', {
                      'count': '$_historyCount',
                    })
                  : l10n.t('coachHealthy'),
          trailingValue: '${insights.length}',
          trailingLabel: l10n.t('coachInsightsCount'),
          badge: insights.isEmpty
              ? l10n.t('coachNoWarning')
              : urgentCount > 0
                  ? l10n.t('coachUrgencyUrgent')
                  : l10n.t('coachUrgencyImportant'),
          badgeAccent: accent,
        ),
        const SizedBox(height: 14),
        if (_syncing)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(minHeight: 3),
          ),
        InsightMetricGrid(
          tiles: [
            InsightMetricTile(
              label: l10n.t('coachInsightsCount'),
              value: '${insights.length}',
              icon: Icons.lightbulb_rounded,
              accent: MohajonWarm.primary,
            ),
            InsightMetricTile(
              label: l10n.t('coachUrgencyUrgent'),
              value: '$urgentCount',
              icon: Icons.priority_high_rounded,
              accent: urgentCount > 0
                  ? MohajonWarm.red
                  : MohajonWarm.green,
            ),
            InsightMetricTile(
              label: l10n.t('coachCashAtRisk'),
              value: money(cashAtRisk),
              icon: Icons.account_balance_wallet_rounded,
              accent: cashAtRisk > 0
                  ? const Color(0xFFEA580C)
                  : MohajonWarm.green,
            ),
          ],
        ),
        if (insights.isEmpty) ...[
          InsightSectionTitle(
            title: l10n.t('coachTodayBrief'),
            icon: Icons.check_circle_rounded,
            accent: MohajonWarm.green,
          ),
          InsightEmptyCard(
            message: l10n.t('coachNoWarning'),
            caption: l10n.t('coachHealthy'),
            icon: Icons.verified_rounded,
            accent: MohajonWarm.green,
          ),
        ] else ...[
          InsightSectionTitle(
            title: l10n.t('coachTodayBrief'),
            icon: Icons.auto_awesome_rounded,
            trailing: InsightBadge(
              label: '${insights.length}',
              accent: accent,
            ),
          ),
          for (final insight in insights) ...[
            _InsightCard(insight: insight, isBangla: isBangla),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight, required this.isBangla});

  final CoachInsight insight;
  final bool isBangla;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = _accentFor(insight.type);
    final urgency = _urgencyFor(insight.priority, l10n);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: InsightTokens.cardDecoration(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [accent, accent.withValues(alpha: 0.62)],
                  ),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.28),
                      blurRadius: 9,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(_iconFor(insight.type), color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isBangla ? insight.titleBn : insight.titleEn,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: MohajonWarm.ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      isBangla ? insight.bodyBn : insight.bodyEn,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: MohajonWarm.muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (insight.amount != null) ...[
                const SizedBox(width: 10),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      money(insight.amount!),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: accent,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    InsightBadge(label: urgency, accent: accent),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.13),
                  accent.withValues(alpha: 0.03),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.22)),
            ),
            child: Row(
              children: [
                Icon(Icons.arrow_forward_rounded, size: 15, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isBangla ? insight.actionBn : insight.actionEn,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
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

IconData _iconFor(CoachInsightType type) => switch (type) {
  CoachInsightType.profitLeak => Icons.trending_down_rounded,
  CoachInsightType.deadStock => Icons.inventory_2_rounded,
  CoachInsightType.riskyCustomer => Icons.account_balance_wallet_rounded,
  CoachInsightType.unusualExpense => Icons.receipt_long_rounded,
};

Color _accentFor(CoachInsightType type) => switch (type) {
  CoachInsightType.profitLeak => MohajonWarm.red,
  CoachInsightType.deadStock => MohajonWarm.orange,
  CoachInsightType.riskyCustomer => const Color(0xFFEA580C),
  CoachInsightType.unusualExpense => const Color(0xFF4F46E5),
};

String _urgencyFor(int priority, AppLocalizations l10n) {
  if (priority >= 90) return l10n.t('coachUrgencyUrgent');
  if (priority >= 70) return l10n.t('coachUrgencyImportant');
  return l10n.t('coachUrgencyWatch');
}