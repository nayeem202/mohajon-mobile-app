import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/app_error.dart';
import '../../../core/widgets/insight_widgets.dart';
import '../providers/accounting_providers.dart';
import 'accounting_widgets.dart';

class AccountingJournalScreen extends ConsumerStatefulWidget {
  const AccountingJournalScreen({super.key});
  @override
  ConsumerState<AccountingJournalScreen> createState() =>
      _AccountingJournalScreenState();
}

class _AccountingJournalScreenState
    extends ConsumerState<AccountingJournalScreen> {
  late DateTimeRange _range;
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateUtils.dateOnly(now),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final result = ref.watch(
      accountingJournalProvider((
        from: accountingDate(_range.start),
        to: accountingDate(_range.end),
      )),
    );
    return PremiumInsightPage(
      expandedHeader: true,
      title: l10n.t('acctJournal'),
      subtitle: l10n.t('acctHistoryNote'),
      icon: Icons.menu_book_rounded,
      children: [
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () async {
            final range = await showDateRangePicker(
              context: context,
              initialDateRange: _range,
              firstDate: DateTime(2000),
              lastDate: DateUtils.dateOnly(DateTime.now()),
            );
            if (range != null && mounted) setState(() => _range = range);
          },
          icon: const Icon(Icons.date_range_rounded),
          label: Text(
            '${accountingDate(_range.start)} — ${accountingDate(_range.end)}',
          ),
        ),
        const SizedBox(height: 14),
        result.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AccountingNotice(
            title: l10n.t('acctFailed'),
            body: friendlyErrorMessage(error, l10n: l10n),
          ),
          data: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (data['_cached'] == true)
                AccountingNotice(
                  title: l10n.t('acctCached'),
                  body: l10n.t('acctCachedHelp'),
                ),
              if ((data['entries'] as List? ?? []).isEmpty)
                AccountingPanel(child: Text(l10n.t('acctNoEntries'))),
              for (final entry
                  in (data['entries'] as List? ?? []).whereType<Map>())
                AccountingPanel(
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: Text(
                      l10n.t('acctSource${entry['sourceType']}'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: MohajonWarm.ink,
                      ),
                    ),
                    subtitle: Text(
                      '${entry['businessDate']} · ${entry['journalKind'] == 'REVERSAL' ? l10n.t('acctTypeREVERSAL') : l10n.t('acctReady')}',
                    ),
                    children: [
                      for (final line
                          in (entry['lines'] as List? ?? []).whereType<Map>())
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Divider(color: MohajonWarm.goldBorder),
                            Text(
                              l10n.t('acctAccount${line['account']}'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            AccountingLine(
                              label: l10n.t('acctDebit'),
                              amount: accountingNumber(line['debit']),
                            ),
                            AccountingLine(
                              label: l10n.t('acctCredit'),
                              amount: accountingNumber(line['credit']),
                            ),
                          ],
                        ),
                      Text(
                        '${entry['sourceId']}',
                        style: const TextStyle(
                          color: MohajonWarm.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
