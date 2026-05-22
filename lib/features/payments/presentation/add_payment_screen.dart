import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/customer.dart';
import '../../../core/models/payment.dart';
import '../../../core/widgets/async_action_state.dart';
import '../providers/payment_providers.dart';

class AddPaymentScreen extends ConsumerStatefulWidget {
  const AddPaymentScreen({super.key, required this.customer});

  final Customer customer;

  @override
  ConsumerState<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends ConsumerState<AddPaymentScreen>
    with AsyncActionState<AddPaymentScreen> {
  final _amount = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return withLoadingOverlay(
      Scaffold(
        appBar: AppBar(title: const Text('Add payment')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              widget.customer.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            const SizedBox(height: 12),
            SegmentedButton<PaymentMethod>(
              segments: const [
                ButtonSegment(value: PaymentMethod.cash, label: Text('Cash')),
                ButtonSegment(value: PaymentMethod.bkash, label: Text('bKash')),
                ButtonSegment(value: PaymentMethod.nagad, label: Text('Nagad')),
              ],
              selected: {_method},
              onSelectionChanged: (value) =>
                  setState(() => _method = value.first),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: isBusy ? null : _savePayment,
              icon: const Icon(Icons.check),
              label: const Text('Save payment'),
            ),
          ],
        ),
      ),
      label: 'Saving payment...',
    );
  }

  Future<void> _savePayment() async {
    await runBusyAction(() async {
      await ref.read(paymentServiceProvider).addPayment(
        customerId: widget.customer.customerId,
        amount: double.tryParse(_amount.text) ?? 0,
        method: _method,
      );
      if (context.mounted) Navigator.of(context).pop();
    });
  }
}
