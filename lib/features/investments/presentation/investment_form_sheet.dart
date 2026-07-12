import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/async_action_state.dart';
import '../models/investment_item.dart';
import '../providers/investment_item_providers.dart';

class InvestmentFormSheet extends ConsumerStatefulWidget {
  const InvestmentFormSheet({super.key, this.investment});

  final InvestmentItem? investment;

  @override
  ConsumerState<InvestmentFormSheet> createState() => _InvestmentFormSheetState();
}

class _InvestmentFormSheetState extends ConsumerState<InvestmentFormSheet>
    with AsyncActionState<InvestmentFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _returnCtrl = TextEditingController();
  final _investorCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _category = '';
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    final inv = widget.investment;
    if (inv != null) {
      _titleCtrl.text = inv.title;
      _descCtrl.text = inv.description;
      _amountCtrl.text = inv.amount.toString();
      _returnCtrl.text = inv.returnAmount.toString();
      _investorCtrl.text = inv.investorName;
      _notesCtrl.text = inv.notes;
      _category = inv.category;
      _date = inv.date;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _returnCtrl.dispose();
    _investorCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.investment != null;
    final colors = Theme.of(context).colorScheme;

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
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: colors.secondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isEditing ? Icons.edit_rounded : Icons.add_chart_rounded,
                        color: colors.secondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEditing ? 'Edit Investment' : 'Add Investment',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _FieldLabel(label: 'Title', required: true),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(hintText: 'e.g. Shop Renovation'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                _FieldLabel(label: 'Amount', required: true),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    hintText: 'e.g. 500000',
                    prefixText: '৳ ',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Required';
                    final amount = double.tryParse(value.trim());
                    if (amount == null || amount <= 0) return 'Enter a valid positive amount';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _FieldLabel(label: 'Category', required: true),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _category.isEmpty ? null : _category,
                  decoration: const InputDecoration(hintText: 'Select category'),
                  items: investmentCategories.map((cat) {
                    return DropdownMenuItem(value: cat, child: Text(cat));
                  }).toList(),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  onChanged: (v) => setState(() => _category = v ?? ''),
                ),
                const SizedBox(height: 14),
                _FieldLabel(label: 'Investor Name'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _investorCtrl,
                  decoration: const InputDecoration(hintText: 'e.g. Rahim Uddin'),
                ),
                const SizedBox(height: 14),
                _FieldLabel(label: 'Investment Date'),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      suffixIcon: Icon(Icons.calendar_month_rounded),
                    ),
                    child: Text(
                      '${_date.day}/${_date.month}/${_date.year}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _FieldLabel(label: 'Description'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(hintText: 'Brief description'),
                ),
                const SizedBox(height: 14),
                _FieldLabel(label: 'Return Amount (so far)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _returnCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    hintText: 'e.g. 50000',
                    prefixText: '৳ ',
                  ),
                ),
                const SizedBox(height: 14),
                _FieldLabel(label: 'Notes'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: 'Additional notes...'),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: isBusy ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(isEditing ? 'Update Investment' : 'Save Investment'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    await runBusyAction(() async {
      await ref.read(investmentItemServiceProvider).save(
        investmentId: widget.investment?.investmentId,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        category: _category,
        investorName: _investorCtrl.text.trim(),
        amount: double.tryParse(_amountCtrl.text.trim()) ?? 0,
        returnAmount: double.tryParse(_returnCtrl.text.trim()) ?? 0,
        notes: _notesCtrl.text.trim(),
        date: _date,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.investment != null ? 'Investment updated' : 'Investment added'),
          ),
        );
      }
    });
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, this.required = false});

  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        children: [
          TextSpan(text: label),
          if (required)
            TextSpan(
              text: ' *',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }
}
