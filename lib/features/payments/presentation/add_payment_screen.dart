import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/sale.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
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
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final openSales = (ref.watch(salesStreamProvider).value ?? const <Sale>[])
        .where((sale) =>
            sale.customerId == widget.customer.customerId && sale.dueAmount > 0)
        .toList();

    return withLoadingOverlay(
      Theme(
        data: MohajonWarm.theme(theme),
        child: Scaffold(
          appBar: AppBar(
            leading: const BackButton(),
            title: Text(l10n.t('receivePayment')),
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: MohajonWarm.pageGradient,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              children: [
                _HeroCard(customer: widget.customer, l10n: l10n),
                const SizedBox(height: 16),
                _AmountCard(
                  controller: _amount,
                  onCurrencyTap: () => setState(() => _saleId = null),
                ),
                const SizedBox(height: 16),
                _InvoiceCard(
                  l10n: l10n,
                  openSales: openSales,
                  saleId: _saleId,
                  onChanged: (value) => setState(() => _saleId = value),
                ),
                const SizedBox(height: 16),
                _MethodCard(
                  l10n: l10n,
                  method: _method,
                  onChanged: (value) => setState(() => _method = value),
                ),
                const SizedBox(height: 24),
                ActionButton(
                  onPressed: _savePayment,
                  isBusy: isBusy,
                  icon: Icons.check_circle_rounded,
                  label: l10n.t('payNow'),
                  busyLabel: l10n.t('savingDots'),
                ),
              ],
            ),
          ),
        ),
      ),
      label: l10n.t('savingPayment'),
    );
  }

  Future<void> _savePayment() async {
    final l10n = AppLocalizations.of(context);
    final amount = double.tryParse(_amount.text) ?? 0;
    if (amount <= 0) {
      showAppSnackBar(context, l10n.t('enterValidAmount'), isError: true);
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
    if (!mounted) return;

    final generateReceipt = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ReceiptDialog(
        title: l10n.t('paymentSuccessful'),
        message: l10n.t('generatePaymentReceipt'),
        generateLabel: l10n.t('generateReceipt'),
        closeLabel: l10n.t('cancel'),
      ),
    );
    if (!mounted) return;

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
        if (mounted) {
          await Printing.sharePdf(
            bytes: bytes,
            filename: 'receipt-PAY-${DateTime.now().millisecondsSinceEpoch}.pdf',
          );
        }
      } catch (e) {
        if (mounted) {
          showAppSnackBar(
            context,
            'Failed to generate receipt: $e',
            isError: true,
          );
        }
      }
    }
    if (mounted) Navigator.of(context).pop();
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.customer, required this.l10n});

  final Customer customer;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(customer.name);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MohajonWarm.primary, MohajonWarm.primaryPale],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MohajonWarm.primary),
        boxShadow: [
          BoxShadow(
            color: MohajonWarm.primary.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Text(
              initials,
              style: const TextStyle(
                color: MohajonWarm.ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('collectPayment'),
                  style: const TextStyle(
                    color: MohajonWarm.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  customer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MohajonWarm.ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (customer.phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    customer.phone,
                    style: const TextStyle(
                      color: MohajonWarm.muted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(
            Icons.payments_rounded,
            color: MohajonWarm.ink,
            size: 30,
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .split(' ')
        .where((p) => p.trim().isNotEmpty)
        .take(2)
        .toList();
    if (parts.isEmpty) return '?';
    return parts.map((p) => p[0].toUpperCase()).join();
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: MohajonWarm.tintYellow,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: MohajonWarm.goldText, size: 19),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: MohajonWarm.ink,
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _WarmCard extends StatelessWidget {
  const _WarmCard({required this.child, this.header});

  final Widget child;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MohajonWarm.goldBorder),
        boxShadow: [
          BoxShadow(
            color: const Color(0x12000000),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ?header,
          if (header != null) const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({required this.controller, required this.onCurrencyTap});

  final TextEditingController controller;
  final VoidCallback onCurrencyTap;

  @override
  Widget build(BuildContext context) {
    return _WarmCard(
      header: const _CardHeader(
        icon: Icons.payments_outlined,
        title: 'Amount',
      ),
      child: TextField(
        controller: controller,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
        ],
        style: const TextStyle(
          color: MohajonWarm.ink,
          fontSize: 24,
          fontWeight: FontWeight.w900,
        ),
        decoration: InputDecoration(
          hintText: '0.00',
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 14, right: 6, top: 16),
            child: Text(
              '৳',
              style: TextStyle(
                color: MohajonWarm.goldText,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 34),
        ),
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({
    required this.l10n,
    required this.openSales,
    required this.saleId,
    required this.onChanged,
  });

  final AppLocalizations l10n;
  final List<Sale> openSales;
  final String? saleId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (openSales.isEmpty) {
      return const SizedBox.shrink();
    }
    return _WarmCard(
      header: _CardHeader(
        icon: Icons.receipt_long_outlined,
        title: l10n.t('applyToInvoice'),
      ),
      child: DropdownButtonFormField<String?>(
        initialValue: saleId,
        isExpanded: true,
        decoration: InputDecoration(
          hintText: l10n.t('customerAccount'),
          prefixIcon: const Icon(
            Icons.account_balance_wallet_outlined,
            color: MohajonWarm.muted,
            size: 20,
          ),
        ),
        items: [
          DropdownMenuItem<String?>(
            value: null,
            child: Text(
              l10n.t('customerAccount'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          for (final sale in openSales)
            DropdownMenuItem<String?>(
              value: sale.saleId,
              child: Text(
                '${l10n.t('customerInvoice')} '
                '${sale.saleId.substring(0, 6).toUpperCase()} • '
                '৳${sale.dueAmount.toStringAsFixed(2)}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.l10n,
    required this.method,
    required this.onChanged,
  });

  final AppLocalizations l10n;
  final PaymentMethod method;
  final ValueChanged<PaymentMethod> onChanged;

  static const _methods = <PaymentMethod>[
    PaymentMethod.cash,
    PaymentMethod.bkash,
    PaymentMethod.nagad,
    PaymentMethod.bank,
    PaymentMethod.other,
  ];

  @override
  Widget build(BuildContext context) {
    return _WarmCard(
      header: _CardHeader(
        icon: Icons.account_balance_wallet_rounded,
        title: l10n.t('choosePaymentMethod'),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final m in _methods)
            _MethodChip(
              method: m,
              selected: method == m,
              l10n: l10n,
              onTap: () => onChanged(m),
            ),
        ],
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip({
    required this.method,
    required this.selected,
    required this.l10n,
    required this.onTap,
  });

  final PaymentMethod method;
  final bool selected;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  String get _label => switch (method) {
        PaymentMethod.cash => l10n.t('cash'),
        PaymentMethod.bkash => l10n.t('bkash'),
        PaymentMethod.nagad => l10n.t('nagad'),
        PaymentMethod.bank => l10n.t('bank'),
        PaymentMethod.other => l10n.t('other'),
        PaymentMethod.credit => l10n.t('credit'),
      };

  IconData get _icon => switch (method) {
        PaymentMethod.cash => Icons.payments_outlined,
        PaymentMethod.bkash => Icons.smartphone_outlined,
        PaymentMethod.nagad => Icons.phone_android_rounded,
        PaymentMethod.bank => Icons.account_balance_outlined,
        PaymentMethod.other => Icons.more_horiz_rounded,
        PaymentMethod.credit => Icons.credit_card_rounded,
      };

  Color get _color => switch (method) {
        PaymentMethod.cash => MohajonWarm.green,
        PaymentMethod.bkash => const Color(0xFFE2136E),
        PaymentMethod.nagad => const Color(0xFFF6921E),
        PaymentMethod.bank => MohajonWarm.goldText,
        PaymentMethod.other => MohajonWarm.muted,
        PaymentMethod.credit => MohajonWarm.orange,
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? _color.withValues(alpha: 0.12)
                : const Color(0xFFFBF7EB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? _color : MohajonWarm.goldBorder,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icon, color: selected ? _color : MohajonWarm.muted, size: 18),
              const SizedBox(width: 8),
              Text(
                _label,
                style: TextStyle(
                  color: selected ? _color : MohajonWarm.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptDialog extends StatelessWidget {
  const _ReceiptDialog({
    required this.title,
    required this.message,
    required this.generateLabel,
    required this.closeLabel,
  });

  final String title;
  final String message;
  final String generateLabel;
  final String closeLabel;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: MohajonWarm.tintGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: MohajonWarm.green,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MohajonWarm.ink,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MohajonWarm.muted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: MohajonWarm.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                child: Text(generateLabel),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MohajonWarm.muted,
                  side: const BorderSide(color: MohajonWarm.goldBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                child: Text(closeLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
