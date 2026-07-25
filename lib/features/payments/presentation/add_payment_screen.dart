import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/models/customer.dart';
import '../../../core/models/payment.dart';
import '../../../core/widgets/action_button.dart';
import '../../../core/widgets/async_action_state.dart';
import '../../receipts/services/receipt_pdf_service.dart';
import '../../receipts/models/receipt.dart';
import '../../settings/providers/shop_profile_providers.dart';
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
            DropdownButtonFormField<PaymentMethod>(
              value: _method,
              decoration: const InputDecoration(labelText: 'Payment Method'),
              items: [
                for (final method in PaymentMethod.values)
                  if (method != PaymentMethod.credit)
                    DropdownMenuItem(
                      value: method,
                      child: Text(method.displayName),
                    ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _method = value);
              },
            ),
            const SizedBox(height: 16),
            ActionButton(
              onPressed: _savePayment,
              isBusy: isBusy,
              icon: Icons.check,
              label: 'Save payment',
              busyLabel: 'Saving...',
            ),
          ],
        ),
      ),
      label: 'Saving payment...',
    );
  }

  Future<void> _savePayment() async {
    final amount = double.tryParse(_amount.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }
    await runBusyAction(() async {
      await ref.read(paymentServiceProvider).addPayment(
        customerId: widget.customer.customerId,
        amount: amount,
        method: _method,
      );
    });
    if (!context.mounted) return;

    final generateReceipt = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Payment Successful'),
        content: const Text('Generate a payment receipt?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Generate Receipt'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;

    if (generateReceipt == true) {
      final shop = ref.read(shopProfileProvider).value;
      final pdfService = ReceiptPdfService();
      final receipt = Receipt(
        companyName: shop?.shopName ?? '',
        companyAddress: shop?.location ?? '',
        companyPhone: shop?.phoneNumber ?? '',
        customerId: widget.customer.customerId,
        customerName: widget.customer.name,
        customerPhone: widget.customer.phone,
        receiptNumber: 'PAY-${DateTime.now().millisecondsSinceEpoch}',
        paymentMethod: _method,
        items: [
          ReceiptItem(
            id: 'payment-${DateTime.now().millisecondsSinceEpoch}',
            productId: 'PAYMENT',
            description: 'Payment received',
            quantity: 1,
            price: amount,
            purchasePrice: 0,
          ),
        ],
        discountType: ReceiptDiscountType.percentage,
        discountPercent: 0,
        discountFixedAmount: 0,
        taxPercent: 0,
        date: DateTime.now(),
      );
      try {
        final bytes = await pdfService.buildReceiptPdf(receipt);
        if (context.mounted) {
          await Printing.sharePdf(
            bytes: bytes,
            filename: 'receipt-PAY-${DateTime.now().millisecondsSinceEpoch}.pdf',
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to generate receipt: $e')),
          );
        }
      }
    }
    if (context.mounted) Navigator.of(context).pop();
  }
}
