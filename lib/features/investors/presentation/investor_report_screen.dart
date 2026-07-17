import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../investments/providers/investment_providers.dart';
import '../providers/investor_providers.dart';

class InvestorReportScreen extends ConsumerWidget {
  const InvestorReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final investors = ref.watch(investorsStreamProvider).value ?? [];
    final overview = ref.watch(investorsOverviewProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F1),
      appBar: AppBar(title: const Text('Investor Report')),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Summary',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 16),
                _Row(label: 'Total Investors', value: '${overview.totalInvestors}'),
                _Row(label: 'Total Invested', value: money(overview.totalInvestment)),
                _Row(label: 'Total Profit', value: money(overview.totalProfit),
                    color: const Color(0xFF047857)),
                _Row(label: 'Total Loss', value: money(overview.totalLoss),
                    color: colors.error),
                _Row(label: 'Outstanding', value: money(overview.totalOutstanding),
                    color: overview.totalOutstanding > 0 ? colors.error : const Color(0xFF047857),
                    showDivider: false),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFECE7DF)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('All Investors',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 12),
                if (investors.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                        child: Text('No investors yet.',
                            style: TextStyle(color: Color(0xFF98A2B3)))),
                  )
                else
                  ...investors.map((inv) => Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: const BoxDecoration(
                          border: Border(
                              bottom: BorderSide(color: Color(0xFFF0ECE4))),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(inv.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800)),
                                  Text(inv.phone.isNotEmpty ? inv.phone : 'No phone',
                                      style: const TextStyle(
                                          color: Color(0xFF667085),
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(money(inv.totalInvestment),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800)),
                                Text(
                                  'Due ${money(inv.outstanding)}',
                                  style: TextStyle(
                                    color: inv.outstanding > 0
                                        ? colors.error
                                        : const Color(0xFF047857),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )),
              ],
            ),
          ),
        ],
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
                child: Text(label,
                    style: const TextStyle(
                        color: Color(0xFF667085),
                        fontWeight: FontWeight.w600)),
              ),
              Text(value,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: color ?? const Color(0xFF101828))),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, color: Color(0xFFF0ECE4)),
      ],
    );
  }
}
