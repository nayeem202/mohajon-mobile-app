import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/app_error.dart';
import '../../../core/widgets/insight_widgets.dart';
import '../providers/accounting_providers.dart';
import 'accounting_widgets.dart';
import 'accounting_setup_screen.dart';
import 'accounting_entry_screen.dart';
import 'accounting_statement_screen.dart';
import 'accounting_journal_screen.dart';

class AccountingWorkspaceScreen extends ConsumerStatefulWidget {
  const AccountingWorkspaceScreen({super.key, this.reviewFirst = false});
  final bool reviewFirst;
  @override
  ConsumerState<AccountingWorkspaceScreen> createState() =>
      _AccountingWorkspaceScreenState();
}

class _AccountingWorkspaceScreenState
    extends ConsumerState<AccountingWorkspaceScreen> {
  void _refresh() => ref.read(accountingRefreshProvider.notifier).state++;
  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(accountingStateProvider);
    return PremiumInsightPage(
      expandedHeader: true,
      title: l10n.t('acctWorkspace'),
      subtitle: l10n.t('acctSubtitle'),
      icon: Icons.account_balance_rounded,
      onRefresh: () async {
        _refresh();
        try {
          await ref.read(accountingStateProvider.future);
        } catch (_) {
          /* Render the error inline. */
        }
      },
      children: [
        const SizedBox(height: 16),
        state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AccountingNotice(
            title: l10n.t('acctFailed'),
            body: friendlyErrorMessage(error, l10n: l10n),
            action: TextButton(
              onPressed: _refresh,
              child: Text(l10n.t('acctRetry')),
            ),
          ),
          data: (data) {
            if (data['configured'] != true) {
              return AccountingNotice(
                title: l10n.t('acctSetupNeeded'),
                body: l10n.t('acctSetupIntro'),
                action: FilledButton.icon(
                  onPressed: () => _open(const AccountingSetupScreen()),
                  icon: const Icon(Icons.account_balance_rounded),
                  label: Text(l10n.t('acctChooseOpening')),
                ),
              );
            }
            final pending = ref.watch(accountingPendingProvider);
            final issues = (data['issues'] as List? ?? const [])
                .whereType<Map>()
                .toList();
            final entries = (data['entries'] as List? ?? const [])
                .whereType<Map>()
                .toList();
            final reversed = entries
                .map((entry) => entry['reversesEntryId'])
                .whereType<String>()
                .toSet();
            final review = <Widget>[
              Text(
                l10n.t('acctReview'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: MohajonWarm.ink,
                ),
              ),
              const SizedBox(height: 10),
              if (issues.isEmpty)
                AccountingPanel(child: Text(l10n.t('acctNoIssues'))),
              for (final issue in issues) _issue(issue, l10n),
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InsightHeroCard(
                  icon: Icons.account_balance_rounded,
                  accent: MohajonWarm.green,
                  title: l10n.t('acctOpeningBalances'),
                  body: '${l10n.t('acctOpeningDate')}: ${data['startDate']}',
                  badge: l10n.t(
                    issues.isEmpty ? 'acctReady' : 'acctNeedsReview',
                  ),
                ),
                const SizedBox(height: 14),
                if (data['_cached'] == true)
                  AccountingNotice(
                    title: l10n.t('acctCached'),
                    body: l10n.t('acctCachedHelp'),
                  ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _open(const AccountingEntryScreen()),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(l10n.t('acctAddEntry')),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _open(const AccountingStatementScreen()),
                      icon: const Icon(Icons.query_stats_rounded),
                      label: Text(l10n.t('acctIncome')),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _open(
                        const AccountingStatementScreen(balanceSheet: true),
                      ),
                      icon: const Icon(Icons.balance_rounded),
                      label: Text(l10n.t('acctBalance')),
                    ),
                    TextButton.icon(
                      onPressed: () => _open(const AccountingSetupScreen()),
                      icon: const Icon(Icons.lock_outline_rounded),
                      label: Text(l10n.t('acctSetup')),
                    ),
                    TextButton.icon(
                      onPressed: () => _open(const AccountingJournalScreen()),
                      icon: const Icon(Icons.receipt_long_rounded),
                      label: Text(l10n.t('acctJournal')),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (pending.isNotEmpty) ...[
                  AccountingNotice(
                    title: l10n.tP('acctPending', {
                      'count': '${pending.length}',
                    }),
                    body: l10n.t('acctCachedHelp'),
                    action: TextButton(
                      onPressed: () async {
                        try {
                          final client = ref.read(accountingClientProvider);
                          await client.outbox.flush(
                            client.shopId,
                            client.branchId,
                            client.userId,
                          );
                          if (mounted) _refresh();
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  friendlyErrorMessage(error, l10n: l10n),
                                ),
                              ),
                            );
                          }
                        }
                      },
                      child: Text(l10n.t('syncNow')),
                    ),
                  ),
                  for (final queued in pending)
                    AccountingPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.t(
                              'acctType${(queued['payload'] as Map)['entryType']}',
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          AccountingLine(
                            label: l10n.t('acctAmount'),
                            amount: accountingNumber(
                              (queued['payload'] as Map)['amount'],
                            ),
                          ),
                          Text(
                            l10n.t(
                              queued['status'] == 'needsReview'
                                  ? 'acctReviewUnderlying'
                                  : 'acctQueued',
                            ),
                          ),
                          if (queued['httpStatus'] == 400)
                            TextButton(
                              onPressed: () => _open(
                                AccountingEntryScreen(
                                  initial: Map<String, dynamic>.from(
                                    queued['payload'] as Map,
                                  ),
                                ),
                              ),
                              child: Text(l10n.t('edit')),
                            ),
                        ],
                      ),
                    ),
                ],
                if (widget.reviewFirst) ...review,
                AccountingPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.t('acctJournal'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.t('acctHistoryNote'),
                        style: const TextStyle(
                          color: MohajonWarm.muted,
                          height: 1.5,
                        ),
                      ),
                      if (entries.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Text(l10n.t('acctNoEntries')),
                        ),
                      for (final entry in entries.take(30)) ...[
                        const Divider(color: MohajonWarm.goldBorder),
                        Text(
                          l10n.t('acctType${entry['entryType']}'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: MohajonWarm.ink,
                          ),
                        ),
                        Text(
                          '${entry['businessDate']}',
                          style: const TextStyle(color: MohajonWarm.muted),
                        ),
                        Text(
                          '${entry['note'] ?? ''}',
                          style: const TextStyle(height: 1.5),
                        ),
                        AccountingLine(
                          label: l10n.t('acctAmount'),
                          amount: accountingNumber(
                            entry['amount'] ??
                                (entry['original'] as Map?)?['amount'],
                          ),
                        ),
                        if (entry['entryType'] != 'REVERSAL' &&
                            !reversed.contains(entry['entryId']))
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              icon: const Icon(Icons.undo_rounded),
                              label: Text(l10n.t('acctReversal')),
                              onPressed: data['_cached'] == true
                                  ? null
                                  : () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (dialogContext) => AlertDialog(
                                          title: Text(l10n.t('acctReversal')),
                                          content: Text(
                                            l10n.t('acctReverseHelp'),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(
                                                dialogContext,
                                                false,
                                              ),
                                              child: Text(l10n.t('cancel')),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(
                                                dialogContext,
                                                true,
                                              ),
                                              child: Text(
                                                l10n.t('acctReverseConfirm'),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirmed != true ||
                                          !context.mounted) {
                                        return;
                                      }
                                      try {
                                        await ref
                                            .read(accountingClientProvider)
                                            .reverse('${entry['entryId']}', {
                                              'entryId': const Uuid().v4(),
                                              'businessDate': accountingDate(
                                                DateTime.now(),
                                              ),
                                              'note': l10n.t('acctReversal'),
                                            });
                                        if (context.mounted) {
                                          _refresh();
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                l10n.t('acctReversed'),
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (error) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                friendlyErrorMessage(
                                                  error,
                                                  l10n: l10n,
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                if (!widget.reviewFirst) ...review,
                Text(
                  l10n.t('acctExportWarning'),
                  style: const TextStyle(
                    color: MohajonWarm.muted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _issue(Map<dynamic, dynamic> issue, AppLocalizations l10n) {
    final key = 'acctIssue${issue['code']}';
    final description = l10n.t(key);
    final canClassify =
        (issue['choices'] as List? ?? []).isNotEmpty ||
        issue['code'] == 'UNKNOWN_PAYMENT_METHOD';
    return AccountingNotice(
      title: l10n.t('acctSource${issue['sourceType']}'),
      body:
          '${description == key ? l10n.t('acctReviewUnderlying') : description}\n${issue['sourceId']}\n${l10n.t('acctAmount')}: ${accountingNumber(issue['amount'])}',
      action: canClassify
          ? TextButton(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AccountingClassificationScreen(
                      issue: Map<String, dynamic>.from(issue),
                    ),
                  ),
                );
                if (mounted) _refresh();
              },
              child: Text(l10n.t('acctReviewAction')),
            )
          : null,
    );
  }
}

class AccountingClassificationScreen extends ConsumerStatefulWidget {
  const AccountingClassificationScreen({super.key, required this.issue});
  final Map<String, dynamic> issue;
  @override
  ConsumerState<AccountingClassificationScreen> createState() =>
      _AccountingClassificationScreenState();
}

class _AccountingClassificationScreenState
    extends ConsumerState<AccountingClassificationScreen> {
  final _form = GlobalKey<FormState>();
  final _note = TextEditingController();
  late final TextEditingController _amount;
  late String _account;
  String _fund = 'CASH';
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    final choices = widget.issue['choices'] as List? ?? [];
    _account = choices.isEmpty ? 'RECEIVABLES' : '${choices.first}';
    _amount = TextEditingController(text: '${widget.issue['amount'] ?? 0}');
  }

  @override
  void dispose() {
    _note.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(accountingClientProvider).classify({
        'sourceType': widget.issue['sourceType'],
        'sourceId': widget.issue['sourceId'],
        'accountCode': _account,
        'fundAccount': _fund,
        'note': _note.text.trim(),
        if (widget.issue['sourceType'] == 'STOCK_ADJUSTMENT' ||
            widget.issue['sourceType'] == 'LEGACY_PAYMENT')
          'amountOverride': parseAccountingAmount(_amount.text),
        if (widget.issue['sourceType'] == 'LEGACY_PAYMENT')
          'businessDateOverride': accountingDate(_date),
      });
      if (!mounted) return;
      ref.read(accountingRefreshProvider.notifier).state++;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.t('acctClassified'))));
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(error, l10n: l10n))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final choices = (widget.issue['choices'] as List? ?? ['RECEIVABLES'])
        .cast<String>();
    final legacy = widget.issue['sourceType'] == 'LEGACY_PAYMENT';
    return AccountingFormScope(
      child: PremiumInsightPage(
        expandedHeader: true,
        title: l10n.t('acctReview'),
        subtitle: l10n.t('acctSource${widget.issue['sourceType']}'),
        icon: Icons.fact_check_rounded,
        children: [
          const SizedBox(height: 16),
          AccountingNotice(
            title: l10n.t('acctClassification'),
            body: l10n.t('acctClassificationHelp'),
          ),
          Form(
            key: _form,
            child: AccountingPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (choices.isNotEmpty)
                    AccountingSelect(
                      label: l10n.t('acctClassification'),
                      value: _account,
                      enabled: !_saving,
                      options: {
                        for (final account in choices)
                          account: l10n.t(
                            account == 'IGNORE'
                                ? 'acctIgnore'
                                : 'acctAccount$account',
                          ),
                      },
                      onChanged: (value) => setState(() => _account = value),
                    ),
                  const SizedBox(height: 18),
                  AccountingSelect(
                    label: l10n.t('acctFund'),
                    value: _fund,
                    enabled: !_saving,
                    options: {
                      for (final fund in fundAccounts)
                        fund: l10n.t('acctAccount$fund'),
                    },
                    onChanged: (value) => setState(() => _fund = value),
                  ),
                  if (legacy ||
                      widget.issue['sourceType'] == 'STOCK_ADJUSTMENT') ...[
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _amount,
                      enabled: !_saving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.t(
                          legacy ? 'acctActualReceipt' : 'acctActualCost',
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (raw) {
                        final value = parseAccountingAmount(raw ?? '');
                        return value == null ||
                                value < 0 ||
                                (!legacy && value == 0)
                            ? l10n.t('acctInvalidAmount')
                            : null;
                      },
                    ),
                  ],
                  if (legacy) ...[
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: _saving
                          ? null
                          : () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _date,
                                firstDate: DateTime(2000),
                                lastDate: DateUtils.dateOnly(DateTime.now()),
                              );
                              if (date != null && mounted) {
                                setState(() => _date = date);
                              }
                            },
                      icon: const Icon(Icons.calendar_month_rounded),
                      label: Text(
                        '${l10n.t('acctHistoricalDate')}: ${accountingDate(_date)}',
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _note,
                    enabled: !_saving,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: InputDecoration(
                      labelText: l10n.t('acctNote'),
                      hintText: l10n.t('acctNoteHint'),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (raw) => (raw?.trim().length ?? 0) < 3
                        ? l10n.t('acctInvalidNote')
                        : null,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        l10n.t('acctSaveClassification'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
