import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/money.dart';
import '../../providers/investment_providers.dart';

class InvestmentReportScreen extends ConsumerWidget {
  const InvestmentReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final investments = ref.watch(investmentsStreamProvider).value ?? [];
    final dashboard = ref.watch(investmentDashboardProvider);
    final totalProfit = investments.fold<double>(0, (s, i) => s + i.totalProfit);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F1),
      appBar: AppBar(title: const Text('Investment Report')),
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
                _ReportRow(label: 'Total Investments', value: '${dashboard.totalInvestments}'),
                _ReportRow(label: 'Total Invested', value: money(dashboard.totalInvested)),
                _ReportRow(label: 'Total Profit', value: money(totalProfit),
                    color: totalProfit >= 0 ? const Color(0xFF047857) : colors.error),
                _ReportRow(label: 'Total Paid', value: money(dashboard.totalReturns)),
                _ReportRow(label: 'Outstanding', value: money(dashboard.totalOutstanding),
                    color: dashboard.totalOutstanding > 0 ? colors.error : const Color(0xFF047857)),
                _ReportRow(label: 'ROI', value: '${dashboard.roi.toStringAsFixed(2)}%',
                    color: dashboard.roi >= 0 ? const Color(0xFF047857) : colors.error,
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
                const Text('All Investments',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 12),
                if (investments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                        child: Text('No investments yet.',
                            style: TextStyle(color: Color(0xFF98A2B3)))),
                  )
                else
                  ...investments.map((inv) => Container(
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
                                  Text(inv.title,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800)),
                                  Text(inv.categoryName,
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
                                Text(money(inv.totalProfit),
                                    style: TextStyle(
                                      color: inv.totalProfit >= 0
                                          ? const Color(0xFF047857)
                                          : colors.error,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    )),
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

class _ReportRow extends StatelessWidget {
  const _ReportRow({
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
