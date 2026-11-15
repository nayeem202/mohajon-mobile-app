import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/app_error.dart';
import '../../../core/widgets/insight_widgets.dart';
import '../providers/accounting_providers.dart';
import 'accounting_widgets.dart';

class AccountingEntryScreen extends ConsumerStatefulWidget {
  const AccountingEntryScreen({super.key, this.initial});
  final Map<String, dynamic>? initial;
  @override
  ConsumerState<AccountingEntryScreen> createState() =>
      _AccountingEntryScreenState();
}

class _AccountingEntryScreenState extends ConsumerState<AccountingEntryScreen> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController(),
      _interest = TextEditingController(text: '0'),
      _note = TextEditingController();
  late String _id;
  String _type = 'CAPITAL_IN', _fund = 'CASH', _destination = 'BANK';
  String? _assetId;
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _id = initial?['entryId'] as String? ?? const Uuid().v4();
    if (initial != null) {
      _type = initial['entryType'] as String? ?? _type;
      _fund = initial['fundAccount'] as String? ?? _fund;
      _destination = initial['toAccount'] as String? ?? _destination;
      _amount.text = '${initial['amount'] ?? ''}';
      _interest.text = '${initial['interest'] ?? 0}';
      _note.text = initial['note'] as String? ?? '';
      _assetId = initial['assetId'] as String?;
      _date = DateTime.tryParse('${initial['businessDate']}') ?? _date;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _interest.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    if (_type == 'FUND_TRANSFER' && _destination == _fund) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.t('acctDifferentFund'))));
      return;
    }
    if (_type == 'DEPRECIATION' && (_assetId ?? '').isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.t('acctChooseAsset'))));
      return;
    }
    setState(() => _saving = true);
    try {
      final posted = await ref.read(accountingClientProvider).addEntry({
        'entryId': _id,
        'entryType': _type,
        'businessDate': accountingDate(_date),
        'amount': parseAccountingAmount(_amount.text),
        'interest': _type == 'LOAN_REPAYMENT'
            ? parseAccountingAmount(_interest.text) ?? 0
            : 0,
        'fundAccount': _fund,
        'toAccount': _destination,
        'assetId': _assetId ?? '',
        'note': _note.text.trim(),
      });
      if (!mounted) return;
      ref.read(accountingRefreshProvider.notifier).state++;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t(posted ? 'acctSaved' : 'acctQueued'))),
      );
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
        title: l10n.t('acctAddEntry'),
        subtitle: l10n.t('acctSubtitle'),
        icon: Icons.post_add_rounded,
        children: [
          const SizedBox(height: 16),
          state.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => AccountingNotice(
              title: l10n.t('acctFailed'),
              body: friendlyErrorMessage(error, l10n: l10n),
            ),
            data: (data) {
              if (data['configured'] != true) {
                return AccountingNotice(
                  title: l10n.t('acctSetupNeeded'),
                  body: l10n.t('acctSetupIntro'),
                );
              }
              final assets = (data['assets'] as List? ?? const [])
                  .whereType<Map>()
                  .toList();
              return Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (data['_cached'] == true)
                      AccountingNotice(
                        title: l10n.t('acctCached'),
                        body: l10n.t('acctCachedHelp'),
                      ),
                    AccountingPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AccountingSelect(
                            label: l10n.t('acctTransactionType'),
                            value: _type,
                            enabled: !_saving,
                            options: {
                              for (final type in financeEntryTypes)
                                type: l10n.t('acctType$type'),
                            },
                            onChanged: (value) => setState(() => _type = value),
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            key: const Key('accounting-entry-amount'),
                            controller: _amount,
                            enabled: !_saving,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: l10n.t(
                                _type == 'LOAN_REPAYMENT'
                                    ? 'acctPrincipal'
                                    : 'acctAmount',
                              ),
                              border: const OutlineInputBorder(),
                            ),
                            validator: (raw) {
                              final value = parseAccountingAmount(raw ?? '');
                              return value == null || value <= 0
                                  ? l10n.t('acctInvalidAmount')
                                  : null;
                            },
                          ),
                          if (_type == 'LOAN_REPAYMENT') ...[
                            const SizedBox(height: 18),
                            TextFormField(
                              controller: _interest,
                              enabled: !_saving,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: l10n.t('acctInterest'),
                                border: const OutlineInputBorder(),
                              ),
                              validator: (raw) {
                                final value = parseAccountingAmount(raw ?? '');
                                return value == null || value < 0
                                    ? l10n.t('acctInvalidOpening')
                                    : null;
                              },
                            ),
                          ],
                          const SizedBox(height: 18),
                          if (_type != 'DEPRECIATION' &&
                              !_type.startsWith('STOCK_'))
                            AccountingSelect(
                              label: l10n.t('acctFund'),
                              value: _fund,
                              enabled: !_saving,
                              options: {
                                for (final fund in fundAccounts)
                                  fund: l10n.t('acctAccount$fund'),
                              },
                              onChanged: (value) =>
                                  setState(() => _fund = value),
                            ),
                          if (_type == 'FUND_TRANSFER') ...[
                            const SizedBox(height: 18),
                            AccountingSelect(
                              label: l10n.t('acctDestination'),
                              value: _destination,
                              enabled: !_saving,
                              options: {
                                for (final fund in fundAccounts)
                                  fund: l10n.t('acctAccount$fund'),
                              },
                              onChanged: (value) =>
                                  setState(() => _destination = value),
                            ),
                          ],
                          if (_type == 'DEPRECIATION') ...[
                            if (assets.isEmpty)
                              Text(l10n.t('acctNoAssets'))
                            else
                              AccountingSelect(
                                label: l10n.t('acctAsset'),
                                value: _assetId,
                                enabled: !_saving,
                                options: {
                                  for (final asset in assets)
                                    '${asset['assetId']}':
                                        asset['assetId'] == 'OPENING'
                                        ? l10n.t('acctOpeningAsset')
                                        : '${asset['name']}',
                                },
                                onChanged: (value) =>
                                    setState(() => _assetId = value),
                              ),
                            const SizedBox(height: 10),
                            Text(
                              l10n.t('acctAssetHelp'),
                              style: const TextStyle(
                                color: MohajonWarm.muted,
                                height: 1.5,
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          OutlinedButton.icon(
                            onPressed: _saving
                                ? null
                                : () async {
                                    final start =
                                        DateTime.tryParse(
                                          '${data['startDate']}',
                                        ) ??
                                        DateTime(2000);
                                    final selected = await showDatePicker(
                                      context: context,
                                      initialDate: _date.isBefore(start)
                                          ? start
                                          : _date,
                                      firstDate: start,
                                      lastDate: DateUtils.dateOnly(
                                        DateTime.now(),
                                      ),
                                    );
                                    if (selected != null && mounted) {
                                      setState(() => _date = selected);
                                    }
                                  },
                            icon: const Icon(Icons.event_rounded),
                            label: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text(
                                '${l10n.t('acctBusinessDate')}: ${accountingDate(_date)}',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            key: const Key('accounting-entry-note'),
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
                        ],
                      ),
                    ),
                    if (_type == 'ASSET_PURCHASE' || _type == 'DEPRECIATION')
                      AccountingNotice(
                        title: l10n.t('acctAsset'),
                        body: l10n.t('acctAssetDateHelp'),
                      ),
                    if (_type.startsWith('STOCK_'))
                      AccountingNotice(
                        title: l10n.t('acctAccountINVENTORY'),
                        body: l10n.t('acctStockHelp'),
                      ),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          l10n.t('acctSave'),
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
