import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/mohajon_warm_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/insight_widgets.dart';
import '../../../../core/widgets/premium_header.dart';
import '../../providers/investment_providers.dart';

class OutstandingReportScreen extends ConsumerWidget {
  const OutstandingReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final investments = ref.watch(investmentsStreamProvider).value ?? [];
    final outstanding = investments.where((inv) => inv.outstanding > 0).toList()
      ..sort((a, b) => b.outstanding.compareTo(a.outstanding));
    final totalOutstanding = outstanding.fold<double>(
      0,
      (s, i) => s + i.outstanding,
    );

    return Theme(
      data: MohajonWarm.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: MohajonWarm.pageGradient),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              children: [
                const PremiumHeader(
                  title: 'Outstanding Report',
                  subtitle: 'Pending dues',
                  icon: Icons.hourglass_top_rounded,
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        MohajonWarm.red.withValues(alpha: 0.1),
                        MohajonWarm.red.withValues(alpha: 0.02),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: MohajonWarm.red.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: MohajonWarm.red,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Outstanding',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              money(totalOutstanding),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 24,
                                color: MohajonWarm.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${outstanding.length} investments',
                        style: const TextStyle(
                          color: MohajonWarm.red,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (outstanding.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Text(
                        'No outstanding amounts!',
                        style: TextStyle(
                          color: MohajonWarm.muted,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  )
                else
                  ...outstanding.map(
                    (inv) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: InsightTokens.cardDecoration(
                        radius: 18,
                        accent: MohajonWarm.red,
                      ),
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
                                  color: MohajonWarm.red.withValues(
                                    alpha: 0.14,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet_rounded,
                              color: MohajonWarm.red,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  inv.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: MohajonWarm.ink,
                                  ),
                                ),
                                Text(
                                  inv.categoryName,
                                  style: const TextStyle(
                                    color: MohajonWarm.muted,
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
                                  fontWeight: FontWeight.w600,
                                  color: MohajonWarm.muted,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                money(inv.outstanding),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: MohajonWarm.red,
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
        ),
      ),
    );
  }
}
