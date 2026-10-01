import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/api_client.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/insight_widgets.dart';

class CashflowRadarScreen extends ConsumerStatefulWidget {
  const CashflowRadarScreen({super.key});

  @override
  ConsumerState<CashflowRadarScreen> createState() =>
      _CashflowRadarScreenState();
}

class _CashflowRadarScreenState extends ConsumerState<CashflowRadarScreen> {
  Map<String, dynamic>? _data;
  double _scenario = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await ApiClient(ref.read(localDatabaseProvider)).getJson(
            '/api/v1/cashflow/radar',
            query: {'salesChangePercent': _scenario.toStringAsFixed(0)},
          );
      if (mounted && result is Map<String, dynamic>) {
        setState(() => _data = result);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(AppLocalizations.of(context).t('cashflowSyncFailed')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final l10n = AppLocalizations.of(context);
    final risk = d?['risk']?.toString() ?? '';
    final accent = risk == 'HIGH'
        ? MohajonWarm.red
        : risk == 'MEDIUM'
            ? MohajonWarm.orange
            : MohajonWarm.green;

    final outlook = d == null
        ? l10n.t('cashflowLoading')
        : risk == 'HIGH'
            ? l10n.t('cashflowGap')
            : l10n.t('cashflowSustainable');

    return PremiumInsightPage(
      title: l10n.t('cashflowTitle'),
      subtitle: l10n.t('featureCashflowRadarSubtitle'),
      icon: Icons.radar_rounded,
      onRefresh: _load,
      children: [
        const SizedBox(height: 18),
        InsightHeroCard(
          icon: Icons.radar_rounded,
          accent: accent,
          title: l10n.t('cashflowOutlook'),
          body: outlook,
          trailingValue: risk.isEmpty ? '—' : risk,
          trailingLabel: l10n.t('featureCashflowRadar'),
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
              label: l10n.t('cashflowIn'),
              value: money((d?['currentCashIn30d'] as num?) ?? 0),
              icon: Icons.south_west_rounded,
              accent: MohajonWarm.green,
            ),
            InsightMetricTile(
              label: l10n.t('cashflowOut'),
              value: money((d?['currentCashOut30d'] as num?) ?? 0),
              icon: Icons.north_east_rounded,
              accent: MohajonWarm.orange,
            ),
            InsightMetricTile(
              label: l10n.t('cashflowOutstanding'),
              value: money((d?['outstandingDue'] as num?) ?? 0),
              icon: Icons.account_balance_wallet_rounded,
              accent: const Color(0xFFEA580C),
            ),
            InsightMetricTile(
              label: l10n.t('cashflowRunway'),
              value: '${d?['runwayDays'] ?? '—'}',
              icon: Icons.timelapse_rounded,
              accent: const Color(0xFF4F46E5),
              caption: 'days',
            ),
          ],
        ),
        const SizedBox(height: 4),
        InsightSectionTitle(
          title: l10n.t('cashflowScenario'),
          icon: Icons.tune_rounded,
          trailing: InsightBadge(
            label: '${_scenario > 0 ? '+' : ''}${_scenario.toStringAsFixed(0)}%',
            accent: _scenario < 0 ? MohajonWarm.red : MohajonWarm.green,
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: InsightTokens.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.t('cashflowScenarioHint'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: MohajonWarm.muted,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Text(
                    '-20%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: MohajonWarm.muted,
                    ),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: accent,
                        thumbColor: accent,
                        overlayColor: accent.withValues(alpha: 0.14),
                        inactiveTrackColor: accent.withValues(alpha: 0.18),
                      ),
                      child: Slider(
                        value: _scenario,
                        min: -20,
                        max: 20,
                        divisions: 8,
                        label: '${_scenario.toStringAsFixed(0)}%',
                        onChanged: (value) => setState(() => _scenario = value),
                        onChangeEnd: (_) => _load(),
                      ),
                    ),
                  ),
                  const Text(
                    '+20%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: MohajonWarm.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.14),
                      accent.withValues(alpha: 0.03),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: 0.22)),
                ),
                child: Text(
                  l10n.tP('cashflowProjected', {
                    'amount': money((d?['projected30dNet'] as num?) ?? 0),
                  }),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}