import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/money.dart';
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

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F1),
      appBar: AppBar(title: const Text('Payout History')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFECE7DF)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.payments_rounded,
                      color: Color(0xFF0F766E)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Payouts',
                          style: TextStyle(
                              color: Color(0xFF667085),
                              fontWeight: FontWeight.w600,
                              fontSize: 12)),
                      Text(money(totalPaid),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            color: Color(0xFF101828),
                          )),
                    ],
                  ),
                ),
                Text('${allPayouts.length} transactions',
                    style: const TextStyle(
                        color: Color(0xFF667085),
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
                    style: TextStyle(color: Color(0xFF98A2B3))),
              ),
            )
          else
            ...allPayouts.map((payout) {
              final inv = investments.where((i) => i.id == payout.investmentId).firstOrNull;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFECE7DF)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        size: 20, color: Color(0xFF047857)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            inv?.title ?? 'Unknown Investment',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF101828)),
                          ),
                          if (payout.note.isNotEmpty)
                            Text(payout.note,
                                style: const TextStyle(
                                    color: Color(0xFF667085), fontSize: 12)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(money(payout.amount),
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF101828))),
                        Text(
                          '${payout.createdAt.day}/${payout.createdAt.month}/${payout.createdAt.year}',
                          style: const TextStyle(
                              color: Color(0xFF98A2B3), fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
