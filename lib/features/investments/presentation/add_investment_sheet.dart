import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../core/widgets/action_button.dart';
import '../../../core/widgets/async_action_state.dart';
import '../../investors/presentation/widgets/investor_selector.dart';
import '../models/investment_category.dart';
import '../providers/investment_providers.dart';
import '../providers/investment_service.dart';

class AddInvestmentSheet extends ConsumerStatefulWidget {
  const AddInvestmentSheet({super.key});

  @override
  ConsumerState<AddInvestmentSheet> createState() =>
      _AddInvestmentSheetState();
}

class _AddInvestmentSheetState extends ConsumerState<AddInvestmentSheet>
    with AsyncActionState<AddInvestmentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _categoryId = '';
  String _categoryName = '';
  String _profitMethod = 'proportional';
  List<SelectedInvestor> _selectedInvestors = [];

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final catsAsync = ref.watch(investmentCategoriesStreamProvider);
    final loaded = catsAsync.value;
    final _categories =
        (loaded != null && loaded.isNotEmpty) ? loaded : InvestmentCategory.defaults;
    final totalInvestment = _selectedInvestors
        .fold<double>(0, (s, si) => s + si.investmentAmount);
    final hasInvalid = _selectedInvestors.any((si) => si.investorId.isEmpty);
    final hasZeroAmount =
        _selectedInvestors.any((si) => si.investmentAmount <= 0);

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Form(
            key: _formKey,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Add Investment',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF101828))),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _FieldLabel(label: 'Description'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    hintText: 'e.g. New shelf installation',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                const _FieldLabel(label: 'Amount & Category'),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          hintText: 'Amount',
                          prefixText: '৳ ',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Required';
                          }
                          final amt = double.tryParse(v.trim());
                          if (amt == null || amt <= 0) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _categoryId.isEmpty ? null : _categoryId,
                        decoration: const InputDecoration(
                          hintText: 'Category',
                        ),
                        items: (_categories)
                            .map((cat) => DropdownMenuItem(
                                  value: cat.id,
                                  child: Text(cat.name),
                                ))
                            .toList(),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                        onChanged: (v) {
                          if (v == null) return;
                          final cat =
                              _categories.firstWhere((c) => c.id == v);
                          setState(() {
                            _categoryId = v;
                            _categoryName = cat.name;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const _FieldLabel(label: 'Profit Share Method'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F5F0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _MethodToggle(
                          label: 'Proportional',
                          selected: _profitMethod == 'proportional',
                          onTap: () =>
                              setState(() => _profitMethod = 'proportional'),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _MethodToggle(
                          label: 'Fixed %',
                          selected: _profitMethod == 'fixed',
                          onTap: () =>
                              setState(() => _profitMethod = 'fixed'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _profitMethod == 'proportional'
                      ? 'Profit is shared proportionally based on investment amount. Share % is auto-calculated.'
                      : 'Profit is shared based on fixed percentage assigned to each investor.',
                  style: TextStyle(
                      color: const Color(0xFF98A2B3),
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                const _FieldLabel(label: 'Investors'),
                const SizedBox(height: 6),
                InvestorSelector(
                  selectedInvestors: _selectedInvestors,
                  onChanged: (list) {
                    final totalAmount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
                    if (_profitMethod == 'proportional' && totalAmount > 0) {
                      list = list.map((si) => SelectedInvestor(
                        investorId: si.investorId,
                        investmentAmount: si.investmentAmount,
                        sharePercentage: (si.investmentAmount / totalAmount) * 100,
                      )).toList();
                    }
                    setState(() => _selectedInvestors = list);
                  },
                  showSharePercentage: true,
                  autoCalculatePercentage: _profitMethod == 'proportional',
                ),
                const SizedBox(height: 20),
                const _FieldLabel(label: 'Notes'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Additional notes...',
                  ),
                ),
                const SizedBox(height: 24),
                ActionButton(
                  onPressed: (hasInvalid ||
                          hasZeroAmount ||
                          _selectedInvestors.isEmpty)
                      ? null
                      : _save,
                  isBusy: isBusy,
                  icon: Icons.save_rounded,
                  label: 'Save Investment',
                  busyLabel: 'Saving...',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedInvestors.any((si) => si.investorId.isEmpty)) return;

    final totalAmount = double.tryParse(_amountCtrl.text.trim()) ?? 0;

    // Distribute total amount proportionally if in proportional mode
    List<MemberInput> members;
    if (_profitMethod == 'proportional') {
      members = _selectedInvestors
          .map((si) => MemberInput(
              investorId: si.investorId,
              investmentAmount: si.investmentAmount))
          .toList();
    } else {
      final totalShare =
          _selectedInvestors.fold<double>(0, (s, si) => s + si.sharePercentage);
      if (totalShare <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Total share percentage must be > 0')),
          );
        }
        return;
      }
      members = _selectedInvestors
          .map((si) => MemberInput(
              investorId: si.investorId,
              investmentAmount: totalAmount * (si.sharePercentage / totalShare),
              sharePercentage: si.sharePercentage))
          .toList();
    }

    try {
      await runBusyAction(() async {
        await ref.read(investmentServiceProvider).createInvestment(
          title: _descCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          categoryId: _categoryId,
          categoryName: _categoryName,
          profitShareMethod: _profitMethod,
          notes: _notesCtrl.text.trim(),
          members: members,
        );
      });
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Investment created successfully'),
              backgroundColor: Color(0xFF047857)),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $error')),
        );
      }
    }
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF101828),
            fontSize: 14));
  }
}

class _MethodToggle extends StatelessWidget {
  const _MethodToggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFF97316)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF667085),
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
