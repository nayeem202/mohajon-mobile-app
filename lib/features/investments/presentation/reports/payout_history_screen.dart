import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/mohajon_warm_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/premium_header.dart';
import '../../models/payout.dart';
import '../../providers/investment_providers.dart';

class PayoutHistoryScreen extends ConsumerStatefulWidget {
  const PayoutHistoryScreen({super.key, this.investmentId});

  final String? investmentId;

  @override
  ConsumerState<PayoutHistoryScreen> createState() =>
      _PayoutHistoryScreenState();
}

class _PayoutHistoryScreenState extends ConsumerState<PayoutHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final investments = ref.watch(investmentsStreamProvider).value ?? [];
    final allPayouts = <Payout>[];

    for (final inv in investments) {
      final payouts = ref.watch(payoutsStreamProvider(inv.id)).value ?? [];
      allPayouts.addAll(payouts);
    }
    allPayouts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final totalPaid = allPayouts.fold<double>(0, (s, p) => s + p.amount);

    return Theme(
      data: MohajonWarm.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: MohajonWarm.pageGradient,
          ),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              children: [
                const PremiumHeader(
                  title: 'Payout History',
                  subtitle: 'All recorded payouts',
                  icon: Icons.receipt_long_rounded,
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MohajonWarm.card,
                    border: Border.all(color: MohajonWarm.goldBorder),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: MohajonWarm.tintYellow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.payments_rounded,
                            color: MohajonWarm.goldText),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Payouts',
                                style: TextStyle(
                                    color: MohajonWarm.muted,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12)),
                            Text(money(totalPaid),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22,
                                  color: MohajonWarm.ink,
                                )),
                          ],
                        ),
                      ),
                      Text('${allPayouts.length} transactions',
                          style: const TextStyle(
                              color: MohajonWarm.muted,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (allPayouts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text('No payouts recorded yet.',
                          style: TextStyle(color: MohajonWarm.muted)),
                    ),
                  )
                else
                  ...allPayouts.map((payout) {
                    final inv = investments
                        .where((i) => i.id == payout.investmentId)
                        .firstOrNull;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: MohajonWarm.card,
                        border: Border.all(color: MohajonWarm.goldBorder),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              size: 20, color: MohajonWarm.green),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  inv?.title ?? 'Unknown Investment',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: MohajonWarm.ink),
                                ),
                                if (payout.note.isNotEmpty)
                                  Text(payout.note,
                                      style: const TextStyle(
                                          color: MohajonWarm.muted,
                                          fontSize: 12)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(money(payout.amount),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: MohajonWarm.ink)),
                              Text(
                                '${payout.createdAt.day}/${payout.createdAt.month}/${payout.createdAt.year}',
                                style: const TextStyle(
                                    color: MohajonWarm.muted, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
