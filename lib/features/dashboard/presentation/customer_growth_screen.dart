import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/api_client.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/widgets/insight_widgets.dart';

class CustomerGrowthScreen extends ConsumerStatefulWidget {
  const CustomerGrowthScreen({super.key});

  @override
  ConsumerState<CustomerGrowthScreen> createState() =>
      _CustomerGrowthScreenState();
}

class _CustomerGrowthScreenState extends ConsumerState<CustomerGrowthScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final value = await ApiClient(ref.read(localDatabaseProvider))
          .get('/api/v1/customer-growth');
      if (mounted) setState(() => _data = value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).t('growthSyncFailed')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final segments =
        (_data?['segments'] as Map?)?.map(
              (key, value) => MapEntry(
                key.toString(),
                value is List ? value : const <dynamic>[],
              ),
            ) ??
            const <String, dynamic>{};
    final recommendations =
        (_data?['recommendations'] as List?)?.whereType<Map<String, dynamic>>().toList() ??
            const <Map<String, dynamic>>[];

    final totalCustomers = segments.values.fold<int>(
      0,
      (sum, value) => sum + (value as List).length,
    );
    final vipCount = (segments['VIP'] as List?)?.length ?? 0;
    final atRiskCount = (segments['AT_RISK'] as List?)?.length ?? 0;
    final accent = atRiskCount > 0
        ? MohajonWarm.orange
        : MohajonWarm.green;

    return PremiumInsightPage(
      title: l10n.t('growthTitle'),
      subtitle: l10n.t('featureCustomerGrowthSubtitle'),
      icon: Icons.insights_rounded,
      onRefresh: _load,
      children: [
        const SizedBox(height: 18),
        InsightHeroCard(
          icon: Icons.insights_rounded,
          accent: accent,
          title: l10n.t('growthBrief'),
          body: l10n.t('growthSegments'),
          trailingValue: '$totalCustomers',
          trailingLabel: l10n.t('growthSegments'),
          badge: recommendations.isEmpty
              ? l10n.t('growthNone')
              : '${recommendations.length}',
          badgeAccent: recommendations.isEmpty ? MohajonWarm.green : accent,
        ),
        const SizedBox(height: 14),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(minHeight: 3),
          ),
        InsightMetricGrid(
          tiles: [
            InsightMetricTile(
              label: l10n.t('segmentVip'),
              value: '$vipCount',
              icon: Icons.workspace_premium_rounded,
              accent: MohajonWarm.green,
            ),
            InsightMetricTile(
              label: l10n.t('segmentAtRisk'),
              value: '$atRiskCount',
              icon: Icons.report_problem_rounded,
              accent: MohajonWarm.orange,
            ),
            InsightMetricTile(
              label: l10n.t('segmentNew'),
              value: '${(segments['NEW'] as List?)?.length ?? 0}',
              icon: Icons.person_add_alt_rounded,
              accent: const Color(0xFF4F46E5),
            ),
            InsightMetricTile(
              label: l10n.t('segmentInactive'),
              value: '${(segments['INACTIVE'] as List?)?.length ?? 0}',
              icon: Icons.hourglass_empty_rounded,
              accent: MohajonWarm.muted,
            ),
          ],
        ),
        InsightSectionTitle(
          title: l10n.t('growthSegments'),
          icon: Icons.donut_small_rounded,
        ),
        if (segments.isEmpty)
          InsightEmptyCard(
            message: l10n.t('growthNone'),
            icon: Icons.groups_rounded,
            accent: MohajonWarm.muted,
          )
        else
          for (final entry in segments.entries) ...[
            InsightRowTile(
              icon: _segmentIcon(entry.key),
              accent: _segmentAccent(entry.key),
              title: entry.key,
              body: _segmentDescription(entry.key, l10n),
              trailing: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _segmentAccent(entry.key).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _segmentAccent(entry.key).withValues(alpha: 0.24),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${entry.value.length}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: _segmentAccent(entry.key),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        InsightSectionTitle(
          title: l10n.t('growthActions'),
          icon: Icons.campaign_rounded,
          accent: const Color(0xFFEA580C),
        ),
        if (recommendations.isEmpty)
          InsightEmptyCard(
            message: l10n.t('growthNone'),
            icon: Icons.check_circle_rounded,
            accent: MohajonWarm.green,
          )
        else
          for (final item in recommendations) ...[
            InsightRowTile(
              icon: Icons.campaign_rounded,
              accent: const Color(0xFFEA580C),
              title: _recommendationTitle(item['segment']?.toString(), l10n),
              body: '${_recommendationBody(item['segment']?.toString(), l10n)}\n'
                  'Customers: ${item['count'] ?? 0}',
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

IconData _segmentIcon(String key) => switch (key) {
  'VIP' => Icons.workspace_premium_rounded,
  'INACTIVE' => Icons.hourglass_empty_rounded,
  'AT_RISK' => Icons.report_problem_rounded,
  'NEW' => Icons.person_add_alt_rounded,
  'REGULAR' => Icons.thumb_up_rounded,
  _ => Icons.people_alt_rounded,
};

Color _segmentAccent(String key) => switch (key) {
  'VIP' => MohajonWarm.green,
  'INACTIVE' => MohajonWarm.muted,
  'AT_RISK' => MohajonWarm.orange,
  'NEW' => const Color(0xFF4F46E5),
  'REGULAR' => MohajonWarm.primary,
  _ => MohajonWarm.muted,
};

String _segmentDescription(String key, AppLocalizations l10n) => switch (key) {
  'VIP' => l10n.t('segmentVip'),
  'INACTIVE' => l10n.t('segmentInactive'),
  'AT_RISK' => l10n.t('segmentAtRisk'),
  'NEW' => l10n.t('segmentNew'),
  'REGULAR' => l10n.t('segmentRegular'),
  _ => l10n.t('customerGroup'),
};

String _recommendationTitle(String? segment, AppLocalizations l10n) =>
    switch (segment) {
  'INACTIVE' => l10n.t('growthInactiveTitle'),
  'VIP' => l10n.t('growthVipTitle'),
  'AT_RISK' => l10n.t('growthRiskTitle'),
  _ => l10n.t('growthActions'),
};

String _recommendationBody(String? segment, AppLocalizations l10n) =>
    switch (segment) {
  'INACTIVE' => l10n.t('growthInactiveBody'),
  'VIP' => l10n.t('growthVipBody'),
  'AT_RISK' => l10n.t('growthRiskBody'),
  _ => l10n.t('growthBrief'),
};