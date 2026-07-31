import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/models/customer.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/product.dart';
import '../../../core/models/sale.dart';
import '../../../core/services/invoice_service.dart';
import '../../../core/utils/money.dart';
import '../../products/providers/product_providers.dart';
import '../providers/cart_provider.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key, required this.customers});

  final List<Customer> customers;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

enum _CustomerMode { walkIn, existing }
enum _DiscountMode { flat, percent }

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _discountController = TextEditingController(text: '0');
  final _vatCustomController = TextEditingController(text: '0');
  final _customerSearchController = TextEditingController();

  _CustomerMode _customerMode = _CustomerMode.walkIn;
  _DiscountMode _discountMode = _DiscountMode.flat;
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  double _vatPercent = 0;
  String _customerQuery = '';
  bool _isCheckingOut = false;

  @override
  void initState() {
    super.initState();
    final cart = ref.read(cartProvider);
    if (cart.customerId.isNotEmpty) {
      _customerMode = _CustomerMode.existing;
    }
  }

  @override
  void dispose() {
    _discountController.dispose();
    _vatCustomController.dispose();
    _customerSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final controller = ref.read(cartProvider.notifier);
    final allProducts = ref.watch(productsProvider).value ?? const <Product>[];
    final productImageMap = <String, String>{};
    for (final p in allProducts) {
      if (p.imagePath != null) productImageMap[p.productId] = p.imagePath!;
    }
    Customer? selectedCustomer;
    for (final customer in widget.customers) {
      if (customer.customerId == cart.customerId) {
        selectedCustomer = customer;
        break;
      }
    }
    final filteredCustomers = widget.customers.where((customer) {
      final query = _customerQuery.trim().toLowerCase();
      if (query.isEmpty) return true;
      return customer.name.toLowerCase().contains(query) ||
          customer.phone.toLowerCase().contains(query);
    }).toList();

    final vatAmount = cart.subtotal * (_vatPercent / 100);
    final discountAmount = _discountAmount(cart.subtotal, vatAmount);
    final total = (cart.subtotal + vatAmount - discountAmount).clamp(
      0,
      double.infinity,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F1),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _isCheckingOut
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const Expanded(
                    child: Text(
                      'Checkout',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF101828),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionTitle(
                      title: 'Customer',
                      trailing: 'Optional',
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<_CustomerMode>(
                      segments: const [
                        ButtonSegment(
                          value: _CustomerMode.walkIn,
                          icon: Icon(Icons.radio_button_checked_rounded, size: 18),
                          label: Text('Walk-in'),
                        ),
                        ButtonSegment(
                          value: _CustomerMode.existing,
                          icon: Icon(Icons.person_outline_rounded, size: 18),
                          label: Text('Existing Client'),
                        ),
                      ],
                      selected: {_customerMode},
                      onSelectionChanged: (selection) {
                        final mode = selection.first;
                        setState(() {
                          _customerMode = mode;
                          if (mode == _CustomerMode.walkIn) {
                            controller.setCustomer('');
                            if (_paymentMethod == PaymentMethod.credit) {
                              _paymentMethod = PaymentMethod.cash;
                            }
                          }
                        });
                      },
                      style: SegmentedButton.styleFrom(
                        backgroundColor: const Color(0xFFF5EEE5),
                        selectedBackgroundColor: const Color(0xFFFF8A00),
                        selectedForegroundColor: Colors.white,
                        foregroundColor: const Color(0xFF9A5A1B),
                        side: const BorderSide(color: Color(0xFFE5D9C9)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_customerMode == _CustomerMode.walkIn)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFCF6ED),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE9D8BD)),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: Color(0xFFFF8A00),
                              size: 18,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Anonymous walk-in sale - no customer info needed',
                                style: TextStyle(
                                  color: Color(0xFF9A5A1B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      TextField(
                        controller: _customerSearchController,
                        onChanged: (value) => setState(() => _customerQuery = value),
                        decoration: const InputDecoration(
                          hintText: 'Search client by name or phone...',
                          prefixIcon: Icon(Icons.search_rounded, size: 20),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE9E1D8)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0B1F17).withValues(alpha: 0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 180),
                          child: ListView.separated(
                            padding: const EdgeInsets.all(8),
                            shrinkWrap: true,
                            itemCount: filteredCustomers.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 12),
                            itemBuilder: (context, index) {
                              final customer = filteredCustomers[index];
                              final selected = customer.customerId == cart.customerId;
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                leading: customer.imagePath != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: Image.file(
                                          File(customer.imagePath!),
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => _CustomerInitials(name: customer.name),
                                        ),
                                      )
                                    : _CustomerInitials(name: customer.name),
                                title: Text(
                                  customer.name,
                                  style: TextStyle(
                                    fontWeight:
                                        selected ? FontWeight.w900 : FontWeight.w700,
                                    color: const Color(0xFF101828),
                                  ),
                                ),
                                subtitle: Text(
                                  customer.phone,
                                  style: const TextStyle(
                                    color: Color(0xFFB48258),
                                  ),
                                ),
                                trailing: selected
                                    ? const Icon(
                                        Icons.check_circle_rounded,
                                        color: Color(0xFFFF8A00),
                                      )
                                    : null,
                                onTap: () => controller.setCustomer(customer.customerId),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    _SectionTitle(title: 'Items (${cart.items.length})'),
                    const SizedBox(height: 10),
                    if (cart.items.isEmpty)
                      const _EmptyCart()
                    else
                      Column(
                        children: [
                          for (var index = 0; index < cart.items.length; index++) ...[
                            if (index != 0) const SizedBox(height: 10),
                            _CheckoutItemRow(
                              item: cart.items[index],
                              imagePath: productImageMap[cart.items[index].productId],
                              onMinus: () => controller.setQty(
                                cart.items[index].productId,
                                cart.items[index].qty - 1,
                              ),
                              onPlus: () => controller.setQty(
                                cart.items[index].productId,
                                cart.items[index].qty + 1,
                              ),
                              onDelete: () => controller.setQty(
                                cart.items[index].productId,
                                0,
                              ),
                            ),
                          ],
                        ],
                      ),
                    const SizedBox(height: 18),
                    _SectionTitle(title: 'VAT'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBF6ED),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE8D5BD)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _RateChip(
                                label: '0%',
                                selected: _vatPercent == 0,
                                onTap: () => setState(() {
                                  _vatPercent = 0;
                                  _vatCustomController.text = '0';
                                }),
                              ),
                              _RateChip(
                                label: '5%',
                                selected: _vatPercent == 5,
                                onTap: () => setState(() {
                                  _vatPercent = 5;
                                  _vatCustomController.text = '5';
                                }),
                              ),
                              _RateChip(
                                label: '7.5%',
                                selected: _vatPercent == 7.5,
                                onTap: () => setState(() {
                                  _vatPercent = 7.5;
                                  _vatCustomController.text = '7.5';
                                }),
                              ),
                              _RateChip(
                                label: '10%',
                                selected: _vatPercent == 10,
                                onTap: () => setState(() {
                                  _vatPercent = 10;
                                  _vatCustomController.text = '10';
                                }),
                              ),
                              _RateChip(
                                label: '15%',
                                selected: _vatPercent == 15,
                                onTap: () => setState(() {
                                  _vatPercent = 15;
                                  _vatCustomController.text = '15';
                                }),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: const Color(0xFFE5D9C9)),
                                ),
                                child: SizedBox(
                                  width: 36,
                                  child: TextField(
                                    controller: _vatCustomController,
                                    keyboardType: const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    textAlign: TextAlign.center,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.]'),
                                      ),
                                    ],
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      suffixText: '%',
                                      suffixStyle: TextStyle(
                                        color: Color(0xFF9A5A1B),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                    style: const TextStyle(
                                      color: Color(0xFF9A5A1B),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                    onChanged: (value) {
                                      final parsed = double.tryParse(value);
                                      if (parsed == null) return;
                                      setState(() => _vatPercent = parsed);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'VAT Amount (${_vatPercent.toStringAsFixed(_vatPercent % 1 == 0 ? 0 : 1)}%)',
                                style: const TextStyle(
                                  color: Color(0xFF9A5A1B),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                money(vatAmount),
                                style: const TextStyle(
                                  color: Color(0xFF7A2E00),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SectionTitle(title: 'Discount'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBF6ED),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE8D5BD)),
                      ),
                      child: Column(
                        children: [
                          SegmentedButton<_DiscountMode>(
                            segments: const [
                              ButtonSegment(
                                value: _DiscountMode.flat,
                                label: Text('Flat (৳)'),
                              ),
                              ButtonSegment(
                                value: _DiscountMode.percent,
                                label: Text('Percent (%)'),
                              ),
                            ],
                            selected: {_discountMode},
                            onSelectionChanged: (selection) {
                              setState(() => _discountMode = selection.first);
                            },
                            style: SegmentedButton.styleFrom(
                              selectedBackgroundColor: const Color(0xFFFF8A00),
                              selectedForegroundColor: Colors.white,
                              foregroundColor: const Color(0xFF9A5A1B),
                              side: const BorderSide(color: Color(0xFFE5D9C9)),
                              shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _discountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]'),
                              ),
                            ],
                            decoration: InputDecoration(
                              prefixText: _discountMode == _DiscountMode.flat
                                  ? '৳ '
                                  : null,
                              suffixText: _discountMode == _DiscountMode.percent
                                  ? '%'
                                  : null,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SectionTitle(title: 'Payment Method'),
                    const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.2,
                      children: [
                        _PaymentTile(
                          label: 'Cash',
                          icon: Icons.payments_rounded,
                          selected: _paymentMethod == PaymentMethod.cash,
                          onTap: () => setState(
                            () => _paymentMethod = PaymentMethod.cash,
                          ),
                        ),
                        _PaymentTile(
                          label: 'bKash',
                          icon: Icons.phone_android_rounded,
                          selected: _paymentMethod == PaymentMethod.bkash,
                          onTap: () => setState(
                            () => _paymentMethod = PaymentMethod.bkash,
                          ),
                        ),
                        _PaymentTile(
                          label: 'Nagad',
                          icon: Icons.account_balance_wallet_rounded,
                          selected: _paymentMethod == PaymentMethod.nagad,
                          onTap: () => setState(
                            () => _paymentMethod = PaymentMethod.nagad,
                          ),
                        ),
                        _PaymentTile(
                          label: 'Credit',
                          icon: Icons.credit_card_rounded,
                          selected: _paymentMethod == PaymentMethod.credit,
                          enabled: _customerMode == _CustomerMode.existing,
                          onTap: () => setState(
                            () => _paymentMethod = PaymentMethod.credit,
                          ),
                        ),
                        _PaymentTile(
                          label: 'Bank',
                          icon: Icons.account_balance_rounded,
                          selected: _paymentMethod == PaymentMethod.bank,
                          onTap: () => setState(
                            () => _paymentMethod = PaymentMethod.bank,
                          ),
                        ),
                        _PaymentTile(
                          label: 'Other',
                          icon: Icons.more_horiz_rounded,
                          selected: _paymentMethod == PaymentMethod.other,
                          onTap: () => setState(
                            () => _paymentMethod = PaymentMethod.other,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F5EF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE8D5BD)),
                      ),
                      child: Column(
                        children: [
                          _TotalLine(label: 'Subtotal', value: money(cart.subtotal)),
                          _TotalLine(label: 'VAT', value: money(vatAmount)),
                          _TotalLine(
                            label: 'Discount',
                            value: '- ${money(discountAmount)}',
                          ),
                          const Divider(height: 18, color: Color(0xFFE6D7C6)),
                          _TotalLine(
                            label: 'Total',
                            value: money(total),
                            emphasized: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isCheckingOut ||
                            cart.items.isEmpty ||
                            (_customerMode == _CustomerMode.existing &&
                                cart.customerId.isEmpty)
                        ? null
                        : () async {
                            setState(() => _isCheckingOut = true);
                            try {
                              final controller = ref.read(cartProvider.notifier);
                              controller.setVatPercent(_vatPercent);
                              controller.setDiscount(discountAmount);
                              controller.setPaymentMethod(_paymentMethod);
                              controller.setPaidAmount(_paymentMethod == PaymentMethod.credit ? 0 : total.toDouble());
                              if (_customerMode == _CustomerMode.walkIn) {
                                controller.setCustomer('');
                              }
                              final sale = await controller.checkout();
                              if (mounted) {
                                Navigator.of(context).pop();
                                final bytes =
                                    await InvoiceService().buildSaleInvoice(
                                  sale,
                                  customerName: selectedCustomer?.name ?? '',
                                  customerPhone: selectedCustomer?.phone ?? '',
                                );
                                await Printing.sharePdf(
                                  bytes: bytes,
                                  filename: 'invoice-${sale.saleId}.pdf',
                                );
                              }
                            } catch (error) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(error.toString()),
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) {
                                setState(() => _isCheckingOut = false);
                              }
                            }
                          },
                    icon: _isCheckingOut
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.shopping_cart_checkout_rounded),
                    label: Text(
                      _isCheckingOut
                          ? 'Processing checkout...'
                          : 'Checkout & invoice',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _discountAmount(double subtotal, double vatAmount) {
    final raw = double.tryParse(_discountController.text.trim()) ?? 0;
    final base = subtotal + vatAmount;
    return switch (_discountMode) {
      _DiscountMode.flat => raw.clamp(0, base).toDouble(),
      _DiscountMode.percent => (base * (raw / 100)).clamp(0, base).toDouble(),
    };
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF7A4A22),
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
              fontSize: 13,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(
              color: Color(0xFFB48258),
              fontSize: 12,
            ),
          ),
      ],
    );
  }
}

class _CheckoutItemRow extends StatelessWidget {
  const _CheckoutItemRow({
    required this.item,
    required this.onMinus,
    required this.onPlus,
    required this.onDelete,
    this.imagePath,
  });

  final SaleItem item;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onDelete;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        imagePath != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(imagePath!),
                  width: 42,
                  height: 42,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _defaultIcon(),
                ),
              )
            : _defaultIcon(),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF7A2E00),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${money(item.unitPrice)} x ${_formatQuantity(item.qty)} = ${money(item.lineTotal)}',
                style: const TextStyle(
                  color: Color(0xFFB48258),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onMinus,
          icon: const Icon(Icons.remove_rounded),
        ),
        Text(
          _formatQuantity(item.qty),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF101828),
          ),
        ),
        SizedBox(
          width: 36,
          height: 36,
          child: Material(
            color: const Color(0xFFF97316),
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: onPlus,
              borderRadius: BorderRadius.circular(18),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
            ),
          ),
        ),
        IconButton(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
        ),
      ],
    );
  }

  Widget _defaultIcon() => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: const Color(0xFFF6E0C8),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Icon(
      Icons.shopping_bag_rounded,
      color: Color(0xFFB45309),
      size: 20,
    ),
  );
}

class _CustomerInitials extends StatelessWidget {
  const _CustomerInitials({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: const Color(0xFFFCE2C8),
      child: Text(
        _initials(name),
        style: const TextStyle(
          color: Color(0xFFB45309),
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _RateChip extends StatelessWidget {
  const _RateChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFF8A00) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFFFF8A00) : const Color(0xFFE5D9C9),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF9A5A1B),
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final enabled = this.enabled || selected;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: enabled ? onTap : null,
      child: Container(
        width: 150,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFF8A00) : (enabled ? const Color(0xFFF5EEE5) : const Color(0xFFEDE5D8)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFFFF8A00) : const Color(0xFFE5D9C9),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : (enabled ? const Color(0xFF9A5A1B) : const Color(0xFFC0B09A)),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : (enabled ? const Color(0xFF9A5A1B) : const Color(0xFFC0B09A)),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalLine extends StatelessWidget {
  const _TotalLine({
    required this.label,
    required this.value,
    this.emphasized = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool emphasized;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: emphasized ? FontWeight.w900 : FontWeight.w600,
              color: const Color(0xFF7A4A22),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? const Color(0xFF101828),
              fontWeight: emphasized ? FontWeight.w900 : FontWeight.w800,
              fontSize: emphasized ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFCF6ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9D8BD)),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            color: Color(0xFFFF8A00),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Select products to start a sale',
              style: TextStyle(
                color: Color(0xFF9A5A1B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
  final initials = parts.take(2).map((part) => part.substring(0, 1).toUpperCase()).join();
  return initials.isEmpty ? '?' : initials;
}

String _formatQuantity(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}
