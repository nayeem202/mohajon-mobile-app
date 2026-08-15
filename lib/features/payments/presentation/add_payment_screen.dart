import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/models/customer.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/sale.dart';
import '../../../core/utils/snackbar.dart';
import '../../../core/widgets/action_button.dart';
import '../../../core/widgets/async_action_state.dart';
import '../../receipts/services/receipt_pdf_service.dart';
import '../../receipts/models/receipt.dart';
import '../../settings/providers/shop_profile_providers.dart';
import '../providers/payment_providers.dart';
import '../../customers/providers/customer_providers.dart';

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
  String? _saleId;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final openSales = (ref.watch(salesStreamProvider).value ?? const <Sale>[])
        .where((sale) =>
            sale.customerId == widget.customer.customerId && sale.dueAmount > 0)
        .toList();
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
            if (openSales.isNotEmpty) ...[
              DropdownButtonFormField<String?>(
                value: _saleId,
                decoration: const InputDecoration(labelText: 'Apply to invoice (optional)'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Customer account / advance'),
                  ),
                  for (final sale in openSales)
                    DropdownMenuItem<String?>(
                      value: sale.saleId,
                      child: Text('Invoice ${sale.saleId.substring(0, 6).toUpperCase()} • Due ৳${sale.dueAmount.toStringAsFixed(2)}'),
                    ),
                ],
                onChanged: (value) => setState(() => _saleId = value),
              ),
              const SizedBox(height: 12),
            ],
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
      showAppSnackBar(context, 'Enter a valid amount', isError: true);
      return;
    }
    await runBusyAction(() async {
      await ref.read(paymentServiceProvider).addPayment(
        customerId: widget.customer.customerId,
        saleId: _saleId,
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
          showAppSnackBar(context, 'Failed to generate receipt: $e', isError: true);
        }
      }
    }
    if (context.mounted) Navigator.of(context).pop();
  }
}
