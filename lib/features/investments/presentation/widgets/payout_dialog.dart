import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/mohajon_warm_theme.dart';
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
    final totalDue = (member.investmentAmount + member.profit)
        .clamp(0.0, double.infinity)
        .toDouble();
    final remaining = member.remainingAmount
        .clamp(0.0, double.infinity)
        .toDouble();
    final investor =
        ref.watch(memberInvestorProvider(member.investorId));
    final l10n = AppLocalizations.of(context);

    return Theme(
      data: MohajonWarm.theme(Theme.of(context)),
      child: Dialog(
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
                      Expanded(
                        child: Text(l10n.t('recordPayout'),
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                                color: MohajonWarm.ink)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: MohajonWarm.ink),
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
                            MohajonWarm.primary.withValues(alpha: 0.12),
                        child: Text(
                          investor != null && investor.name.isNotEmpty
                              ? investor.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                              color: MohajonWarm.goldText,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(investor?.name ?? l10n.t('unknown'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: MohajonWarm.ink)),
                            Text(l10n.t('investmentReturnPayout'),
                                style: const TextStyle(
                                    color: MohajonWarm.muted, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _PStat(
                          label: l10n.t('totalDue'),
                          value: money(totalDue),
                          color: MohajonWarm.goldText),
                      const SizedBox(width: 8),
                      _PStat(
                          label: l10n.t('paid'),
                          value: money(member.paidAmount),
                          color: MohajonWarm.green),
                      const SizedBox(width: 8),
                      _PStat(
                          label: l10n.t('remaining'),
                          value: money(remaining),
                          color: remaining > 0
                              ? MohajonWarm.red
                              : MohajonWarm.green),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: l10n.t('payoutAmount'),
                      hintText: l10n.t('enterAmount'),
                      prefixText: '৳ ',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return l10n.t('amountRequired');
                      }
                      final amount = double.tryParse(value.trim());
                      if (amount == null || amount <= 0) {
                        return l10n.t('enterValidAmount');
                      }
                      if (amount > remaining) {
                        return l10n.tP('cannotExceed', {
                          'amount': money(remaining),
                        });
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: l10n.t('date'),
                        suffixIcon: const Icon(Icons.calendar_month_rounded),
                      ),
                      child: Text(
                        '${_date.day}/${_date.month}/${_date.year}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _noteCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: l10n.t('optionalNote'),
                      hintText: l10n.t('monthlyPayoutHint'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: MohajonWarm.tintYellow,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: MohajonWarm.goldBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                size: 16, color: MohajonWarm.orange),
                            const SizedBox(width: 6),
                            Text(l10n.t('howPayoutsWork'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: MohajonWarm.orange,
                                    fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${l10n.t('payoutHelp1')}\n'
                          '${l10n.t('payoutHelp2')}\n'
                          '${l10n.t('payoutHelp3')}',
                          style: const TextStyle(
                              color: MohajonWarm.goldText,
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
                    label: l10n.t('savePayout'),
                    busyLabel: l10n.t('saving'),
                  ),
                ],
              ),
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
    final l10n = AppLocalizations.of(context);

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
        showAppSnackBar(context, l10n.t('payoutRecordedSuccess'));
      }
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, '${l10n.t('failed')}: $error', isError: true);
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
