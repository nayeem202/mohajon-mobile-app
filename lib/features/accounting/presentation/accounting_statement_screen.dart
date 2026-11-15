import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/app_user.dart';
import '../../../core/app/app_providers.dart';
import '../../../core/services/pdf_doc.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/app_error.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/insight_widgets.dart';
import '../../reports/presentation/report_shared_widgets.dart';
import '../../settings/providers/shop_profile_providers.dart';
import '../../branches/presentation/branches_screen.dart';
import '../../branches/providers/branch_providers.dart';
import '../providers/accounting_providers.dart';
import '../data/accounting_export.dart';
import 'accounting_widgets.dart';
import 'accounting_setup_screen.dart';
import 'accounting_workspace_screen.dart';

class AccountingStatementScreen extends ConsumerStatefulWidget {
  const AccountingStatementScreen({super.key, this.balanceSheet = false});
  final bool balanceSheet;
  @override
  ConsumerState<AccountingStatementScreen> createState() =>
      _AccountingStatementScreenState();
}

class _AccountingStatementScreenState
    extends ConsumerState<AccountingStatementScreen>
    with ReportExportMixin {
  late bool _balance;
  late DateTimeRange _range;
  DateTime _asOf = DateUtils.dateOnly(DateTime.now());
  @override
  void initState() {
    super.initState();
    _balance = widget.balanceSheet;
    final now = DateTime.now();
    _range = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateUtils.dateOnly(now),
    );
  }

  AccountingQuery get _query => (
    kind: _balance ? 'balance' : 'income',
    from: accountingDate(_range.start),
    to: accountingDate(_balance ? _asOf : _range.end),
  );
  void _refresh() => ref.read(accountingRefreshProvider.notifier).state++;
  Future<void> _pick() async {
    final today = DateUtils.dateOnly(DateTime.now());
    if (_balance) {
      final date = await showDatePicker(
        context: context,
        initialDate: _asOf,
        firstDate: DateTime(2000),
        lastDate: today,
      );
      if (date != null && mounted) setState(() => _asOf = date);
    } else {
      final range = await showDateRangePicker(
        context: context,
        initialDateRange: _range,
        firstDate: DateTime(2000),
        lastDate: today,
      );
      if (range != null && mounted) setState(() => _range = range);
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _refresh();
  }

  Future<void> _export(Map<String, dynamic> data, bool pdf) async {
    final l10n = AppLocalizations.of(context);
    await runExport(
      isXlsx: !pdf,
      message: l10n.t('dataExportComplete'),
      task: () async {
        await saveAccountingExport(
          accountingReportTable(data, l10n, balanceSheet: _balance),
          DocCompany.fromShop(ref.read(shopProfileProvider).value),
          pdf: pdf,
          balanceSheet: _balance,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (ref.watch(currentUserProvider)?.role != UserRole.owner) {
      return PremiumInsightPage(
        title: l10n.t('acctWorkspace'),
        subtitle: l10n.t('acctSubtitle'),
        icon: Icons.account_balance_rounded,
        children: [
          AccountingNotice(
            title: l10n.t('acctOwnerOnly'),
            body: l10n.t('acctQualityHelp'),
          ),
        ],
      );
    }
    final result = ref.watch(accountingReportProvider(_query));
    final selectedBranch = ref.watch(currentBranchIdProvider);
    final branches = ref.watch(branchesProvider).value ?? const [];
    final branchName =
        branches
            .where((branch) => branch.branchId == selectedBranch)
            .firstOrNull
            ?.name ??
        l10n.t(
          selectedBranch == null || selectedBranch.endsWith('-main')
              ? 'acctDefaultBranch'
              : 'acctCurrentBranch',
        );
    return PremiumInsightPage(
      expandedHeader: true,
      title: l10n.t(_balance ? 'acctBalance' : 'acctIncome'),
      subtitle: l10n.t('acctSubtitle'),
      icon: _balance ? Icons.balance_rounded : Icons.query_stats_rounded,
      onRefresh: () async {
        _refresh();
        try {
          await ref.read(accountingReportProvider(_query).future);
        } catch (_) {
          /* Error is rendered inline. */
        }
      },
      headerTrailing: IconButton(
        tooltip: l10n.t('acctWorkspace'),
        icon: const Icon(Icons.tune_rounded),
        onPressed: () => _open(const AccountingWorkspaceScreen()),
      ),
      children: [
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () => _open(const BranchesScreen()),
          icon: const Icon(Icons.storefront_rounded),
          label: Text('${l10n.t('branches')}: $branchName', softWrap: true),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: Text(l10n.t('acctIncome')),
                selected: !_balance,
                onSelected: (_) => setState(() => _balance = false),
              ),
              const SizedBox(width: 10),
              ChoiceChip(
                label: Text(l10n.t('acctBalance')),
                selected: _balance,
                onSelected: (_) => setState(() => _balance = true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _pick,
          icon: const Icon(Icons.date_range_rounded),
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _balance
                  ? '${l10n.t('acctAsOf')}: ${accountingDate(_asOf)}'
                  : reportRangeLabel(_range),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 16),
        result.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, _) => AccountingNotice(
            title: l10n.t('acctFailed'),
            body: friendlyErrorMessage(error, l10n: l10n),
            action: Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: _refresh,
                  child: Text(l10n.t('acctRetry')),
                ),
                TextButton(
                  onPressed: () => _open(const AccountingSetupScreen()),
                  child: Text(l10n.t('acctChooseOpening')),
                ),
              ],
            ),
          ),
          data: (data) => _body(data, l10n),
        ),
      ],
    );
  }

  Widget _body(Map<String, dynamic> data, AppLocalizations l10n) {
    final local = data['isLocalEstimate'] == true;
    if (_balance && data['configured'] != true) {
      return AccountingNotice(
        title: l10n.t('acctSetupNeeded'),
        body: l10n.t('acctSetupIntro'),
        action: FilledButton(
          onPressed: () => _open(const AccountingSetupScreen()),
          child: Text(l10n.t('acctChooseOpening')),
        ),
      );
    }
    final profit = accountingNumber(data['netProfit']);
    final issues = (data['issues'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AccountingSummary(
          icon: _balance
              ? Icons.account_balance_wallet_rounded
              : Icons.trending_up_rounded,
          accent: MohajonWarm.green,
          title: l10n.t(_balance ? 'acctTotalAssets' : 'acctMetricNetProfit'),
          body: _balance
              ? '${l10n.t('acctAsOf')}: ${data['asOf']}'
              : '${data['from']} — ${data['to']}',
          trailingValue: money(
            accountingNumber(data[_balance ? 'totalAssets' : 'netProfit']),
          ),
          trailingLabel: l10n.t(
            _balance ? 'acctTotalAssets' : 'acctMetricNetProfit',
          ),
          badge: l10n.t(
            local
                ? 'acctLocalEstimate'
                : data['requiresReview'] == true
                ? 'acctNeedsReview'
                : 'acctReady',
          ),
        ),
        const SizedBox(height: 14),
        if (data['_cached'] == true)
          AccountingNotice(
            title: l10n.t('acctCached'),
            body: l10n.t('acctCachedHelp'),
          ),
        if (accountingNumber(data['_pending']) > 0)
          AccountingNotice(
            title: l10n.tP('acctPending', {'count': '${data['_pending']}'}),
            body: l10n.t('acctCachedHelp'),
          ),
        if (local)
          AccountingNotice(
            title: l10n.t('acctLocalEstimate'),
            body: l10n.t('acctLocalHelp'),
            action: TextButton(
              onPressed: () => _open(const AccountingSetupScreen()),
              child: Text(l10n.t('acctChooseOpening')),
            ),
          ),
        if (data['rangeAdjusted'] == true)
          AccountingNotice(
            title: l10n.t('acctPeriod'),
            body: l10n.t('acctRangeAdjusted'),
          ),
        if (!local && issues.isNotEmpty)
          AccountingNotice(
            title: l10n.t('acctNeedsReview'),
            body: l10n.t('acctQualityHelp'),
            action: TextButton(
              onPressed: () =>
                  _open(const AccountingWorkspaceScreen(reviewFirst: true)),
              child: Text(l10n.t('acctReviewAction')),
            ),
          ),
        if (_balance) ...[
          for (final section in ['assets', 'liabilities', 'equity'])
            AccountingPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.t(
                      'acct${section[0].toUpperCase()}${section.substring(1)}',
                    ),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: MohajonWarm.ink,
                    ),
                  ),
                  for (final row
                      in (data[section] as List? ?? const []).whereType<Map>())
                    AccountingLine(
                      label: l10n.t('acctAccount${row['account']}'),
                      amount: accountingNumber(row['amount']),
                    ),
                  const Divider(color: MohajonWarm.goldBorder),
                  AccountingLine(
                    label: l10n.t(
                      section == 'assets'
                          ? 'acctTotalAssets'
                          : section == 'liabilities'
                          ? 'acctTotalLiabilities'
                          : 'acctTotalEquity',
                    ),
                    amount: accountingNumber(
                      data[section == 'assets'
                          ? 'totalAssets'
                          : section == 'liabilities'
                          ? 'totalLiabilities'
                          : 'totalEquity'],
                    ),
                    emphasis: true,
                  ),
                ],
              ),
            ),
          AccountingNotice(
            title: l10n.t(
              data['isBalanced'] == true ? 'acctBalanced' : 'acctUnbalanced',
            ),
            body:
                '${l10n.t('acctDifference')}: ${money(accountingNumber(data['difference']))}\n${l10n.t('acctQualityHelp')}',
            icon: Icons.balance_rounded,
          ),
        ] else
          AccountingPanel(
            child: Column(
              children: [
                for (final key in incomeMetrics) ...[
                  if (key == 'grossProfit' || key == 'netProfit')
                    const Divider(color: MohajonWarm.goldBorder),
                  AccountingLine(
                    label: l10n.t(metricKey(key)),
                    amount: accountingNumber(data[key]),
                    emphasis: key == 'netProfit',
                    color: key == 'netProfit'
                        ? profit < 0
                              ? MohajonWarm.red
                              : MohajonWarm.green
                        : null,
                  ),
                ],
              ],
            ),
          ),
        Text(
          l10n.t('acctExportWarning'),
          style: const TextStyle(
            color: MohajonWarm.muted,
            fontSize: 12,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: exportingPdf ? null : () => _export(data, true),
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('PDF'),
            ),
            OutlinedButton.icon(
              onPressed: exportingXlsx ? null : () => _export(data, false),
              icon: const Icon(Icons.table_view_rounded),
              label: const Text('Excel'),
            ),
            TextButton.icon(
              onPressed: () => _open(const AccountingWorkspaceScreen()),
              icon: const Icon(Icons.receipt_long_rounded),
              label: Text(l10n.t('acctWorkspace')),
            ),
          ],
        ),
      ],
    );
  }
}
