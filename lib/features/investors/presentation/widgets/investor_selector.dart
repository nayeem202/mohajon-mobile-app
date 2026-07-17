import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/money.dart';
import '../../models/investor.dart';
import '../../providers/investor_providers.dart';

class InvestorSelector extends ConsumerStatefulWidget {
  const InvestorSelector({
    super.key,
    required this.selectedInvestors,
    required this.onChanged,
    this.showSharePercentage = false,
  });

  final List<SelectedInvestor> selectedInvestors;
  final ValueChanged<List<SelectedInvestor>> onChanged;
  final bool showSharePercentage;

  @override
  ConsumerState<InvestorSelector> createState() => _InvestorSelectorState();
}

class _InvestorSelectorState extends ConsumerState<InvestorSelector> {
  @override
  Widget build(BuildContext context) {
    final investorsAsync = ref.watch(investorsStreamProvider);

    return investorsAsync.when(
      data: (investors) => _buildContent(investors),
      error: (e, _) => Text('Error: $e'),
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  Widget _buildContent(List<Investor> investors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...widget.selectedInvestors.asMap().entries.map((entry) {
          final index = entry.key;
          final si = entry.value;
          final investor =
              investors.where((i) => i.id == si.investorId).firstOrNull;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF0ECE4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: si.investorId.isEmpty ? null : si.investorId,
                        decoration: const InputDecoration(
                          labelText: 'Investor *',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        items: investors
                            .map((inv) => DropdownMenuItem(
                                  value: inv.id,
                                  child: Text(inv.name),
                                ))
                            .toList(),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                        onChanged: (v) {
                          if (v == null) return;
                          final list = [...widget.selectedInvestors];
                          list[index] = SelectedInvestor(
                            investorId: v,
                            investmentAmount: si.investmentAmount,
                            sharePercentage: si.sharePercentage,
                          );
                          widget.onChanged(list);
                        },
                      ),
                    ),
                    if (widget.selectedInvestors.length > 1)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded,
                            color: Color(0xFFDC2626)),
                        onPressed: () {
                          final list = [...widget.selectedInvestors];
                          list.removeAt(index);
                          widget.onChanged(list);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: si.investmentAmount == 0
                            ? ''
                            : si.investmentAmount.toString(),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Amount *',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final amt = double.tryParse(v.trim());
                          if (amt == null || amt <= 0) return 'Must be > 0';
                          return null;
                        },
                        onChanged: (v) {
                          final list = [...widget.selectedInvestors];
                          list[index] = SelectedInvestor(
                            investorId: si.investorId,
                            investmentAmount: double.tryParse(v.trim()) ?? 0,
                            sharePercentage: si.sharePercentage,
                          );
                          widget.onChanged(list);
                        },
                      ),
                    ),
                    if (widget.showSharePercentage) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: si.sharePercentage == 0
                              ? ''
                              : si.sharePercentage.toString(),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Share %',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            suffixText: '%',
                          ),
                          onChanged: (v) {
                            final list = [...widget.selectedInvestors];
                            list[index] = SelectedInvestor(
                              investorId: si.investorId,
                              investmentAmount: si.investmentAmount,
                              sharePercentage:
                                  double.tryParse(v.trim()) ?? 0,
                            );
                            widget.onChanged(list);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: _addInvestor,
          icon: const Icon(Icons.person_add_rounded, size: 18),
          label: const Text('Add Investor'),
        ),
      ],
    );
  }

  void _addInvestor() {
    final list = [...widget.selectedInvestors];
    list.add(SelectedInvestor(
      investorId: '',
      investmentAmount: 0,
      sharePercentage: 0,
    ));
    widget.onChanged(list);
  }
}

class SelectedInvestor {
  const SelectedInvestor({
    required this.investorId,
    required this.investmentAmount,
    this.sharePercentage = 0,
  });

  final String investorId;
  final double investmentAmount;
  final double sharePercentage;
}
