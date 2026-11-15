import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/app_error.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/insight_widgets.dart';
import '../providers/accounting_providers.dart';
import 'accounting_widgets.dart';

class AccountingSetupScreen extends ConsumerStatefulWidget {
  const AccountingSetupScreen({super.key});
  @override
  ConsumerState<AccountingSetupScreen> createState() =>
      _AccountingSetupScreenState();
}

class _AccountingSetupScreenState extends ConsumerState<AccountingSetupScreen> {
  final _form = GlobalKey<FormState>();
  final _values = {
    for (final account in openingAccounts)
      account: TextEditingController(text: '0'),
  };
  DateTime _start = DateUtils.dateOnly(DateTime.now());
  bool _confirmed = false, _saving = false;
  @override
  void dispose() {
    for (final controller in _values.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double _value(String key) => parseAccountingAmount(_values[key]!.text) ?? 0;
  double get _assets =>
      [
        'CASH',
        'BANK',
        'MOBILE_MONEY',
        'RECEIVABLES',
        'INVENTORY',
        'FIXED_ASSETS',
      ].fold<double>(0, (sum, key) => sum + _value(key)) -
      _value('ACCUMULATED_DEPRECIATION');
  double get _right => [
    'PAYABLES',
    'LOANS',
    'VAT_PAYABLE',
    'OTHER_LIABILITIES',
    'CAPITAL',
    'RETAINED_EARNINGS',
  ].fold<double>(0, (sum, key) => sum + _value(key));
  bool get _balanced =>
      moneyRound2(_assets - _right) == 0 &&
      _value('ACCUMULATED_DEPRECIATION') <= _value('FIXED_ASSETS');
  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (!_form.currentState!.validate()) return;
    if (!_balanced || !_confirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.t(_confirmed ? 'acctInvalidOpening' : 'acctConfirmRequired'),
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(accountingClientProvider).setup({
        'startDate': accountingDate(_start),
        'balances': {
          for (final account in openingAccounts) account: _value(account),
        },
        'confirmed': true,
      });
      if (!mounted) return;
      ref.read(accountingRefreshProvider.notifier).state++;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.t('acctSetupSaved'))));
      Navigator.of(context).pop(true);
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
    final state = ref.watch(accountingStateProvider);
    return AccountingFormScope(
      child: PremiumInsightPage(
        expandedHeader: true,
        title: l10n.t('acctSetup'),
        subtitle: l10n.t('acctSubtitle'),
        icon: Icons.account_balance_rounded,
        children: [
          const SizedBox(height: 16),
          state.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => AccountingNotice(
              title: l10n.t('acctFailed'),
              body: friendlyErrorMessage(error, l10n: l10n),
              action: TextButton(
                onPressed: () => ref.invalidate(accountingStateProvider),
                child: Text(l10n.t('acctRetry')),
              ),
            ),
            data: (data) {
              if (data['configured'] == true) {
                final values = Map<String, dynamic>.from(
                  data['openingBalances'] as Map? ?? {},
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AccountingNotice(
                      title:
                          '${l10n.t('acctOpeningDate')}: ${data['startDate']}',
                      body: l10n.t('acctSetupLocked'),
                      icon: Icons.lock_outline_rounded,
                    ),
                    AccountingPanel(
                      child: Column(
                        children: [
                          for (final account in openingAccounts)
                            AccountingLine(
                              label: l10n.t('acctAccount$account'),
                              amount: accountingNumber(values[account]),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              }
              if (data['_cached'] == true) {
                return AccountingNotice(
                  title: l10n.t('acctSetup'),
                  body: l10n.t('acctSetupOnline'),
                );
              }
              return Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AccountingNotice(
                      title: l10n.t('acctOpeningBalances'),
                      body: l10n.t('acctSetupIntro'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _saving
                          ? null
                          : () async {
                              final selected = await showDatePicker(
                                context: context,
                                initialDate: _start,
                                firstDate: DateTime(2000),
                                lastDate: DateUtils.dateOnly(DateTime.now()),
                              );
                              if (selected != null && mounted) {
                                setState(() => _start = selected);
                              }
                            },
                      icon: const Icon(Icons.calendar_month_rounded),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          '${l10n.t('acctOpeningDate')}: ${accountingDate(_start)}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      l10n.t('acctOpeningHelp'),
                      style: const TextStyle(
                        color: MohajonWarm.muted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final group in [
                      (
                        'acctAssets',
                        [
                          'CASH',
                          'BANK',
                          'MOBILE_MONEY',
                          'RECEIVABLES',
                          'INVENTORY',
                          'FIXED_ASSETS',
                          'ACCUMULATED_DEPRECIATION',
                        ],
                      ),
                      (
                        'acctLiabilities',
                        [
                          'PAYABLES',
                          'LOANS',
                          'VAT_PAYABLE',
                          'OTHER_LIABILITIES',
                        ],
                      ),
                      ('acctEquity', ['CAPITAL', 'RETAINED_EARNINGS']),
                    ])
                      AccountingPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              l10n.t(group.$1),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                color: MohajonWarm.ink,
                              ),
                            ),
                            for (final account in group.$2)
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: TextFormField(
                                  key: Key('accounting-opening-$account'),
                                  controller: _values[account],
                                  enabled: !_saving,
                                  keyboardType: TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: account == 'RETAINED_EARNINGS',
                                  ),
                                  decoration: InputDecoration(
                                    labelText: l10n.t('acctAccount$account'),
                                    border: const OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                  validator: (raw) {
                                    final amount = parseAccountingAmount(
                                      raw ?? '',
                                    );
                                    if (amount == null ||
                                        (amount < 0 &&
                                            account != 'RETAINED_EARNINGS')) {
                                      return l10n.t('acctInvalidOpening');
                                    }
                                    return null;
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    AccountingPanel(
                      accent: _balanced
                          ? MohajonWarm.green
                          : MohajonWarm.orange,
                      child: Column(
                        children: [
                          AccountingLine(
                            label: l10n.t('acctTotalAssets'),
                            amount: _assets,
                          ),
                          AccountingLine(
                            label:
                                '${l10n.t('acctLiabilities')} + ${l10n.t('acctEquity')}',
                            amount: _right,
                          ),
                          const Divider(color: MohajonWarm.goldBorder),
                          AccountingLine(
                            label: l10n.t('acctDifference'),
                            amount: moneyRound2(_assets - _right),
                            emphasis: true,
                            color: _balanced
                                ? MohajonWarm.green
                                : MohajonWarm.red,
                          ),
                        ],
                      ),
                    ),
                    CheckboxListTile(
                      value: _confirmed,
                      onChanged: _saving
                          ? null
                          : (value) =>
                                setState(() => _confirmed = value ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        l10n.t('acctSetupConfirm'),
                        style: const TextStyle(height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.lock_rounded),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          l10n.t('acctConfirmSetup'),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
