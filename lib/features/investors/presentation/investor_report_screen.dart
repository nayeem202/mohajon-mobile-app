import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/money.dart';
import '../providers/investor_providers.dart';

class InvestorReportScreen extends ConsumerWidget {
  const InvestorReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final investors = ref.watch(investorsStreamProvider).value ?? [];
    final overview = ref.watch(investorsOverviewProvider);
    final l10n = AppLocalizations.of(context);

    return Theme(
      data: MohajonWarm.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(l10n.t('investorReport'))),
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: MohajonWarm.pageGradient),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: MohajonWarm.card.withValues(alpha: .94),
                  border: Border.all(color: MohajonWarm.goldBorder),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('summary'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Row(
                      label: l10n.t('totalInvestors'),
                      value: '${overview.totalInvestors}',
                    ),
                    _Row(
                      label: l10n.t('totalInvested'),
                      value: money(overview.totalInvestment),
                    ),
                    _Row(
                      label: l10n.t('totalProfit'),
                      value: money(overview.totalProfit),
                      color: const Color(0xFF047857),
                    ),
                    _Row(
                      label: l10n.t('totalLoss'),
                      value: money(overview.totalLoss),
                      color: MohajonWarm.red,
                    ),
                    _Row(
                      label: l10n.t('outstanding'),
                      value: money(overview.totalOutstanding),
                      color: overview.totalOutstanding > 0
                          ? MohajonWarm.red
                          : MohajonWarm.green,
                      showDivider: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: MohajonWarm.card.withValues(alpha: .94),
                  border: Border.all(color: MohajonWarm.goldBorder),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('allInvestors'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (investors.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            l10n.t('noInvestorsYet'),
                            style: const TextStyle(color: Color(0xFF98A2B3)),
                          ),
                        ),
                      )
                    else
                      ...investors.map(
                        (inv) => Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Color(0xFFF0ECE4)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      inv.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      inv.phone.isNotEmpty
                                          ? inv.phone
                                          : l10n.t('noPhone'),
                                      style: const TextStyle(
                                        color: Color(0xFF667085),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    money(inv.totalInvestment),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    l10n.tP('dueMoney', {
                                      'amount': money(inv.outstanding),
                                    }),
                                    style: TextStyle(
                                      color: inv.outstanding > 0
                                          ? MohajonWarm.red
                                          : MohajonWarm.green,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.color,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final Color? color;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: MohajonWarm.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: color ?? MohajonWarm.ink,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, color: MohajonWarm.goldBorder),
      ],
    );
  }
}
