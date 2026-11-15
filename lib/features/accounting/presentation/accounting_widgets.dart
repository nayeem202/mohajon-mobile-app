import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../branches/providers/branch_providers.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/widgets/insight_widgets.dart';
import '../../../core/utils/money.dart';

/// A partially filled financial form must never silently move to another scope.
class AccountingFormScope extends ConsumerStatefulWidget {
  const AccountingFormScope({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<AccountingFormScope> createState() =>
      _AccountingFormScopeState();
}

class _AccountingFormScopeState extends ConsumerState<AccountingFormScope> {
  late final (String?, String?, String?) _origin;
  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _origin = (user?.userId, user?.shopId, ref.read(currentBranchIdProvider));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final scope = (
      user?.userId,
      user?.shopId,
      ref.watch(currentBranchIdProvider),
    );
    if (scope == _origin) return widget.child;
    final l10n = AppLocalizations.of(context);
    return PremiumInsightPage(
      expandedHeader: true,
      title: l10n.t('acctWorkspace'),
      subtitle: l10n.t('acctSubtitle'),
      icon: Icons.storefront_rounded,
      children: [
        const SizedBox(height: 16),
        AccountingNotice(
          title: l10n.t('acctScopeChanged'),
          body: l10n.t('acctReopenForm'),
        ),
      ],
    );
  }
}

class AccountingPanel extends StatelessWidget {
  const AccountingPanel({
    super.key,
    required this.child,
    this.accent = MohajonWarm.primary,
  });
  final Widget child;
  final Color accent;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(16),
    decoration: InsightTokens.cardDecoration(radius: 20, accent: accent),
    child: child,
  );
}

/// Financial values have their own full-width row; large balances must never
/// squeeze the title or overflow on a narrow phone at accessibility text sizes.
class AccountingSummary extends StatelessWidget {
  const AccountingSummary({
    super.key,
    required this.icon,
    required this.accent,
    required this.title,
    required this.body,
    required this.trailingValue,
    this.trailingLabel,
    required this.badge,
  });
  final IconData icon;
  final Color accent;
  final String title, body, trailingValue, badge;
  final String? trailingLabel;
  @override
  Widget build(BuildContext context) => AccountingPanel(
    accent: accent,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: MohajonWarm.ink,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            trailingValue,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: const TextStyle(color: MohajonWarm.muted, height: 1.5),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: InsightBadge(label: badge, accent: accent),
        ),
      ],
    ),
  );
}

class AccountingLine extends StatelessWidget {
  const AccountingLine({
    super.key,
    required this.label,
    required this.amount,
    this.emphasis = false,
    this.color,
  });
  final String label;
  final num amount;
  final bool emphasis;
  final Color? color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: LayoutBuilder(
      builder: (context, size) {
        final title = Text(
          label,
          style: TextStyle(
            color: MohajonWarm.muted,
            fontSize: emphasis ? 14 : 13,
            fontWeight: emphasis ? FontWeight.w800 : FontWeight.w600,
          ),
        );
        final value = Text(
          money(amount),
          style: TextStyle(
            color: color ?? MohajonWarm.ink,
            fontSize: emphasis ? 22 : 16,
            fontWeight: FontWeight.w800,
          ),
        );
        if (size.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 5), value],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: title),
            const SizedBox(width: 16),
            Flexible(child: value),
          ],
        );
      },
    ),
  );
}

class AccountingNotice extends StatelessWidget {
  const AccountingNotice({
    super.key,
    required this.title,
    required this.body,
    this.action,
    this.icon = Icons.info_outline_rounded,
  });
  final String title, body;
  final Widget? action;
  final IconData icon;
  @override
  Widget build(BuildContext context) => AccountingPanel(
    accent: MohajonWarm.orange,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: MohajonWarm.goldText, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: MohajonWarm.ink,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: const TextStyle(color: MohajonWarm.muted, height: 1.5),
        ),
        if (action != null) ...[const SizedBox(height: 10), action!],
      ],
    ),
  );
}

/// Full wrapping labels instead of a fixed-height dropdown with ellipses.
class AccountingSelect extends StatelessWidget {
  const AccountingSelect({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
  });
  final String label;
  final String? value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: MohajonWarm.muted,
        ),
      ),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: !enabled
            ? null
            : () async {
                final selected = await showModalBottomSheet<String>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (context) => FractionallySizedBox(
                    heightFactor: .75,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            children: [
                              for (final option in options.entries)
                                ListTile(
                                  title: Text(option.value),
                                  trailing: option.key == value
                                      ? const Icon(
                                          Icons.check_circle_rounded,
                                          color: MohajonWarm.green,
                                        )
                                      : null,
                                  onTap: () =>
                                      Navigator.pop(context, option.key),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                if (context.mounted && selected != null) onChanged(selected);
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Expanded(child: Text(options[value] ?? label, softWrap: true)),
              const SizedBox(width: 8),
              const Icon(Icons.expand_more_rounded),
            ],
          ),
        ),
      ),
    ],
  );
}

const openingAccounts = [
  'CASH',
  'BANK',
  'MOBILE_MONEY',
  'RECEIVABLES',
  'INVENTORY',
  'FIXED_ASSETS',
  'ACCUMULATED_DEPRECIATION',
  'PAYABLES',
  'LOANS',
  'VAT_PAYABLE',
  'OTHER_LIABILITIES',
  'CAPITAL',
  'RETAINED_EARNINGS',
];
const fundAccounts = ['CASH', 'BANK', 'MOBILE_MONEY'];
const financeEntryTypes = [
  'CAPITAL_IN',
  'OWNER_DRAWING',
  'LOAN_RECEIVED',
  'LOAN_REPAYMENT',
  'ASSET_PURCHASE',
  'DEPRECIATION',
  'FUND_TRANSFER',
  'SUPPLIER_REFUND',
  'STOCK_INCREASE',
  'STOCK_DECREASE',
];
double accountingNumber(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
String accountingDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
String metricKey(String value) =>
    'acctMetric${value[0].toUpperCase()}${value.substring(1)}';
double? parseAccountingAmount(String value) {
  const bangla = '০১২৩৪৫৬৭৮৯';
  final converted = value
      .trim()
      .split('')
      .map((character) {
        final index = bangla.indexOf(character);
        return index < 0 ? character : '$index';
      })
      .join()
      .replaceAll(',', '');
  final number = double.tryParse(converted);
  if (number == null || !number.isFinite || number.abs() > 9999999999999.99) {
    return null;
  }
  return number;
}

const incomeMetrics = [
  'salesRevenue',
  'salesReturns',
  'netSales',
  'costOfGoodsSold',
  'grossProfit',
  'otherIncome',
  'operatingExpenses',
  'depreciation',
  'interest',
  'netProfit',
];
