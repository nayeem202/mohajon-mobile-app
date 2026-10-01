import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/api_client.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/insight_widgets.dart';

class BusinessGuardianScreen extends ConsumerStatefulWidget {
  const BusinessGuardianScreen({super.key});

  @override
  ConsumerState<BusinessGuardianScreen> createState() =>
      _BusinessGuardianScreenState();
}

class _BusinessGuardianScreenState extends ConsumerState<BusinessGuardianScreen> {
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
      final value =
          await ApiClient(ref.read(localDatabaseProvider)).get('/api/v1/business-guardian');
      if (mounted) setState(() => _data = value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(AppLocalizations.of(context).t('guardianSyncFailed')),
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
    final alerts =
        (_data?['alerts'] as List?)?.whereType<Map<String, dynamic>>().toList() ??
            const <Map<String, dynamic>>[];
    final events =
        (_data?['events'] as List?)?.whereType<Map<String, dynamic>>().take(20).toList() ??
            const <Map<String, dynamic>>[];

    final score = (_data?['riskScore'] as num?)?.toInt() ?? 0;
    final accent = score >= 60
        ? MohajonWarm.red
        : score > 0
            ? MohajonWarm.orange
            : MohajonWarm.green;
    final scoreFactor = (score / 100).clamp(0.0, 1.0).toDouble();

    return PremiumInsightPage(
      title: l10n.t('guardianTitle'),
      subtitle: l10n.t('featureBusinessGuardianSubtitle'),
      icon: Icons.shield_rounded,
      onRefresh: _load,
      children: [
        const SizedBox(height: 18),
        InsightHeroCard(
          icon: Icons.shield_rounded,
          accent: accent,
          title: l10n.t('guardianProtection'),
          body: score == 0
              ? l10n.t('guardianNormal')
              : l10n.t('guardianReview'),
          trailingValue: '$score',
          trailingLabel: l10n.t('guardianSignals'),
          badge: score == 0 ? l10n.t('dayStatusOpen') : l10n.t('guardianSignals'),
          badgeAccent: accent,
        ),
        const SizedBox(height: 12),
        InsightMeter(value: scoreFactor, accent: accent),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(minHeight: 3),
          ),
        InsightSectionTitle(
          title: l10n.t('guardianSignals'),
          icon: Icons.warning_amber_rounded,
          accent: MohajonWarm.orange,
          trailing: InsightBadge(
            label: '${alerts.length}',
            accent: alerts.isEmpty ? MohajonWarm.green : MohajonWarm.orange,
          ),
        ),
        if (alerts.isEmpty)
          InsightEmptyCard(
            message: l10n.t('guardianEverythingNormal'),
            caption: l10n.t('guardianNewActivity'),
            icon: Icons.verified_user_rounded,
          )
        else
          for (final alert in alerts) ...[
            InsightRowTile(
              icon: _alertIcon(alert['type']?.toString()),
              accent: _alertAccent(alert['type']?.toString()),
              title: _alertTitle(alert['type']?.toString(), l10n),
              body: _alertBody(alert['type']?.toString(), l10n),
              trailing: alert['amount'] == null
                  ? null
                  : Text(
                      money(alert['amount'] as num),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: _alertAccent(alert['type']?.toString()),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
          ],
        InsightSectionTitle(
          title: l10n.t('guardianTimeline'),
          icon: Icons.history_rounded,
          trailing: InsightBadge(label: '${events.length}', accent: MohajonWarm.primary),
        ),
        if (events.isEmpty)
          InsightEmptyCard(
            message: l10n.t('guardianNoActivity'),
            icon: Icons.history_rounded,
            accent: MohajonWarm.muted,
          )
        else
          for (final event in events) ...[
            InsightRowTile(
              icon: Icons.bolt_rounded,
              accent: MohajonWarm.primary,
              title:
                  '${event['action'] ?? 'ACTIVITY'} · ${event['entityType'] ?? ''}',
              body: '${event['entityId'] ?? ''}'
                  '${event['createdAt'] == null ? '' : '\n${event['createdAt']}'}',
              dense: true,
              trailing: event['amount'] == null
                  ? null
                  : Text(
                      money(event['amount'] as num),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: MohajonWarm.ink,
                      ),
                    ),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

IconData _alertIcon(String? type) => switch (type) {
  'large_sale' => Icons.trending_up_rounded,
  'large_expense' => Icons.receipt_long_rounded,
  'deletion' => Icons.delete_outline_rounded,
  _ => Icons.help_outline_rounded,
};

Color _alertAccent(String? type) => switch (type) {
  'large_sale' => MohajonWarm.green,
  'large_expense' => MohajonWarm.orange,
  'deletion' => MohajonWarm.red,
  _ => MohajonWarm.primary,
};

String _alertTitle(String? type, AppLocalizations l10n) => switch (type) {
  'large_sale' => l10n.t('guardianLargeSale'),
  'large_expense' => l10n.t('guardianLargeExpense'),
  'deletion' => l10n.t('guardianDeletion'),
  _ => l10n.t('guardianReview'),
};

String _alertBody(String? type, AppLocalizations l10n) => switch (type) {
  'large_sale' => l10n.t('guardianLargeSaleBody'),
  'deletion' => l10n.t('guardianDeletionBody'),
  _ => l10n.t('guardianReview'),
};