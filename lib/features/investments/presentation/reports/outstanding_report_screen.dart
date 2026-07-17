import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/money.dart';
import '../../providers/investment_providers.dart';

class OutstandingReportScreen extends ConsumerWidget {
  const OutstandingReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final investments = ref.watch(investmentsStreamProvider).value ?? [];
    final outstanding = investments
        .where((inv) => inv.outstanding > 0)
        .toList()
      ..sort((a, b) => b.outstanding.compareTo(a.outstanding));
    final totalOutstanding =
        outstanding.fold<double>(0, (s, i) => s + i.outstanding);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F1),
      appBar: AppBar(title: const Text('Outstanding Report')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors.error.withValues(alpha: 0.1),
                  colors.error.withValues(alpha: 0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.error.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: colors.error, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Outstanding',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(money(totalOutstanding),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                            color: colors.error,
                          )),
                    ],
                  ),
                ),
                Text('${outstanding.length} investments',
                    style: TextStyle(color: colors.error, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (outstanding.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text('No outstanding amounts!',
                    style: TextStyle(color: Color(0xFF98A2B3), fontSize: 16)),
              ),
            )
          else
            ...outstanding.map((inv) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFECE7DF)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(inv.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF101828))),
                            Text(inv.categoryName,
                                style: const TextStyle(
                                    color: Color(0xFF667085), fontSize: 12)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(money(inv.totalInvestment),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF667085),
                                  fontSize: 12)),
                          Text(money(inv.outstanding),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: colors.error,
                              )),
                        ],
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}
