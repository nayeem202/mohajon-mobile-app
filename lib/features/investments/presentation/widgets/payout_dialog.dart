import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/utils/snackbar.dart';
import '../../../../core/widgets/action_button.dart';
import '../../../../core/widgets/async_action_state.dart';
import '../../models/investment_member.dart';
import '../../providers/investment_providers.dart';

class PayoutDialog extends ConsumerStatefulWidget {
  const PayoutDialog({
    super.key,
    required this.investmentId,
    required this.member,
  });

  final String investmentId;
  final InvestmentMember member;

  @override
  ConsumerState<PayoutDialog> createState() => _PayoutDialogState();
}

class _PayoutDialogState extends ConsumerState<PayoutDialog>
    with AsyncActionState<PayoutDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _date = DateTime.now();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.member;
    final totalDue = member.investmentAmount + member.profit;
    final colors = Theme.of(context).colorScheme;
    final investor =
        ref.watch(memberInvestorProvider(member.investorId));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Record Payout',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            color: Color(0xFF101828))),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor:
                        colors.primary.withValues(alpha: 0.12),
                    child: Text(
                      investor != null && investor.name.isNotEmpty
                          ? investor.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(investor?.name ?? 'Unknown',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: Color(0xFF101828))),
                        const Text('Investment return payout',
                            style: TextStyle(
                                color: Color(0xFF667085),
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _PStat(
                      label: 'Total Due',
                      value: money(totalDue),
                      color: colors.primary),
                  const SizedBox(width: 8),
                  _PStat(
                      label: 'Paid',
                      value: money(member.paidAmount),
                      color: const Color(0xFF047857)),
                  const SizedBox(width: 8),
                  _PStat(
                      label: 'Remaining',
                      value: money(member.remainingAmount),
                      color: member.remainingAmount > 0
                          ? colors.error
                          : const Color(0xFF047857)),
                ],
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Payout Amount',
                  hintText: 'Enter amount',
                  prefixText: '৳ ',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Amount is required';
                  }
                  final amount = double.tryParse(value.trim());
                  if (amount == null || amount <= 0) {
                    return 'Enter a valid amount';
                  }
                  if (amount > member.remainingAmount) {
                    return 'Cannot exceed ${money(member.remainingAmount)}';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    suffixIcon: Icon(Icons.calendar_month_rounded),
                  ),
                  child: Text(
                    '${_date.day}/${_date.month}/${_date.year}',
                    style:
                        const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Optional Note',
                  hintText: 'e.g. Monthly payout',
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCE7C8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 16, color: Color(0xFFEA580C)),
                        const SizedBox(width: 6),
                        const Text('How Payouts Work',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF9A3412),
                                fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '• Reduces Outstanding Capital: The payout amount is subtracted from the investment outstanding balance.\n'
                      '• Reduces Net Due: The investor\'s remaining amount (investment + profit - paid) decreases by the payout amount.\n'
                      '• The total paid out for the investment increases, bringing the investor closer to full settlement.',
                      style: TextStyle(
                          color: Color(0xFF9A3412),
                          fontSize: 11,
                          height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ActionButton(
                onPressed: _submit,
                isBusy: isBusy,
                icon: Icons.save_rounded,
                label: 'Save Payout',
                busyLabel: 'Saving...',
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;

    try {
      await runBusyAction(() async {
        await ref.read(investmentServiceProvider).recordPayout(
          investmentId: widget.investmentId,
          investorId: widget.member.investorId,
          amount: amount,
          note: _noteCtrl.text.trim(),
        );
      });
      if (mounted) {
        Navigator.of(context).pop();
        showAppSnackBar(context, 'Payout recorded successfully');
      }
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, 'Failed: $error', isError: true);
      }
    }
  }
}

class _PStat extends StatelessWidget {
  const _PStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: color.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
