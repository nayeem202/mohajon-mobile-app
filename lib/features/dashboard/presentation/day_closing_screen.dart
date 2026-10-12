import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/api_client.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/insight_widgets.dart';

class DayClosingScreen extends ConsumerStatefulWidget {
  const DayClosingScreen({super.key});

  @override
  ConsumerState<DayClosingScreen> createState() => _DayClosingScreenState();
}

class _DayClosingScreenState extends ConsumerState<DayClosingScreen> {
  Map<String, dynamic>? _data;
  final _opening = TextEditingController();
  final _actual = TextEditingController();
  final _note = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _opening.dispose();
    _actual.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final value = await ApiClient(
        ref.read(localDatabaseProvider),
      ).get('/api/v1/day-closing');
      if (mounted) {
        setState(() => _data = value);
        if (value['status'] != 'CLOSED') {
          _opening.text = '${value['openingCash'] ?? 0}';
        }
      }
    } catch (_) {
      // The summary card already shows the empty state; keep the form usable.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _close() async {
    final l10n = AppLocalizations.of(context);
    final opening = double.tryParse(_opening.text.trim());
    final actual = double.tryParse(_actual.text.trim());
    if (opening == null || actual == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.t('dayInvalidCash'))));
      return;
    }
    setState(() => _saving = true);
    try {
      final value = await ApiClient(ref.read(localDatabaseProvider)).post(
        '/api/v1/day-closing',
        {
          'openingCash': opening,
          'actualCash': actual,
          'note': _note.text.trim(),
        },
      );
      if (mounted) {
        setState(() => _data = value);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.t('dayClosedSuccess'))));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.t('dayCloseFailed'))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final data = _data ?? <String, dynamic>{};
    final closed = data['status'] == 'CLOSED';
    final variance = (data['variance'] as num?)?.toDouble();
    final accent = variance == null
        ? const Color(0xFF4F46E5)
        : variance.abs() < 1
        ? MohajonWarm.green
        : MohajonWarm.orange;

    return PremiumInsightPage(
      title: l10n.t('dayClosingTitle'),
      subtitle: l10n.t('featureDayClosingSubtitle'),
      icon: Icons.fact_check_rounded,
      onRefresh: _load,
      children: [
        const SizedBox(height: 18),
        InsightHeroCard(
          icon: Icons.fact_check_rounded,
          accent: accent,
          title: closed
              ? l10n.t('dayClosingLocked')
              : l10n.t('dayClosingBrief'),
          body:
              '${l10n.t('dayClosingExpected')} '
              '${money((data['expectedCash'] ?? data['cashSales']) as num? ?? 0)}',
          trailingValue: money(
            (data['expectedCash'] ?? data['cashSales']) as num? ?? 0,
          ),
          trailingLabel: l10n.t('dayClosingExpected'),
          badge: closed ? l10n.t('dayStatusClosed') : l10n.t('dayStatusOpen'),
          badgeAccent: closed ? MohajonWarm.green : accent,
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
              label: l10n.t('cashSales'),
              value: money((data['cashSales'] as num?) ?? 0),
              icon: Icons.payments_rounded,
              accent: MohajonWarm.green,
            ),
            InsightMetricTile(
              label: l10n.t('digitalSales'),
              value: money((data['digitalSales'] as num?) ?? 0),
              icon: Icons.phone_iphone_rounded,
              accent: const Color(0xFF4F46E5),
            ),
            InsightMetricTile(
              label: l10n.t('expenses'),
              value: money((data['expenses'] as num?) ?? 0),
              icon: Icons.receipt_long_rounded,
              accent: MohajonWarm.orange,
            ),
            InsightMetricTile(
              label: l10n.t('dayClosingExpected'),
              value: money(
                (data['expectedCash'] ?? data['cashSales']) as num? ?? 0,
              ),
              icon: Icons.savings_rounded,
              accent: const Color(0xFFEA580C),
            ),
          ],
        ),
        if (!closed) ...[
          InsightSectionTitle(
            title: l10n.t('dayClosingBrief'),
            icon: Icons.edit_note_rounded,
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: InsightTokens.cardDecoration(
              radius: 20,
              accent: MohajonWarm.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _opening,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.t('dayClosingOpening'),
                    prefixText: '৳ ',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _actual,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.t('dayClosingActual'),
                    prefixText: '৳ ',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _note,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: l10n.t('dayClosingNote'),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _close,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.lock_clock_rounded, size: 19),
                    label: Text(
                      _saving
                          ? l10n.t('dayClosingSaving')
                          : l10n.t('dayClosingButton'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (closed) ...[
          InsightSectionTitle(
            title: l10n.t('dayClosingReconciliation'),
            icon: Icons.balance_rounded,
            accent: accent,
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: InsightTokens.heroDecoration(accent),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    variance != null && variance.abs() < 1
                        ? Icons.verified_rounded
                        : Icons.warning_amber_rounded,
                    color: accent,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.tP('dayClosingVariance', {
                          'amount': money(variance ?? 0),
                        }),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${l10n.t('dayClosingExpected')} '
                        '${money((data['expectedCash'] as num?) ?? 0)} · '
                        '${l10n.t('dayClosingActual')} '
                        '${money((data['actualCash'] as num?) ?? 0)}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: MohajonWarm.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
