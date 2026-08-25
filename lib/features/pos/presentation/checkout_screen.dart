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
import '../../../core/widgets/app_image.dart';
import '../../../core/utils/money.dart';
import '../../products/providers/product_providers.dart';
import '../providers/cart_provider.dart';

const _kAmber = Color(0xFFFFC800);
const _kAmberLight = Color(0xFFFFD83D);
const _kInk = Color(0xFF2F3028);
const _kMuted = Color(0xFF77735F);
const _kCard = Color(0xFFFFFDF7);
const _kPage = Color(0xFFFFFCF0);
const _kBorder = Color(0xFFEADFAE);
const _kSoftFill = Color(0xFFFFF4BF);
const _kWarmTint = Color(0xFFFFF6D5);
const _kBronzeText = Color(0xFF8A6500);

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

  OutlineInputBorder get _fieldBorder => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _kBorder),
      );

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
      backgroundColor: _kPage,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.16],
            colors: [Color(0xFFFFF3CE), _kPage],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 16, 12),
                child: Row(
                  children: [
                    Material(
                      color: Colors.white,
                      shape: const CircleBorder(
                        side: BorderSide(color: _kBorder),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _isCheckingOut
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Padding(
                          padding: EdgeInsets.all(9),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: _kInk,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_kAmber, Color(0xFFFFE36E)],
                        ),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: _kBorder),
                        boxShadow: [
                          BoxShadow(
                            color: _kAmber.withValues(alpha: 0.32),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.shopping_cart_checkout_rounded,
                        color: _kInk,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Checkout',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              color: _kInk,
                              letterSpacing: -0.4,
                            ),
                          ),
                          Text(
                            'Review items & payment',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _kMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (cart.items.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: _kSoftFill,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: _kBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.shopping_bag_rounded,
                              size: 14,
                              color: _kBronzeText,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${cart.items.length} items',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: _kBronzeText,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _SectionHeader(
                        icon: Icons.person_outline_rounded,
                        title: 'Customer',
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _kWarmTint,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _kBorder),
                        ),
                        child: SegmentedButton<_CustomerMode>(
                          segments: const [
                            ButtonSegment(
                              value: _CustomerMode.walkIn,
                              icon: Icon(Icons.directions_walk_rounded, size: 17),
                              label: Text('Walk-in'),
                            ),
                            ButtonSegment(
                              value: _CustomerMode.existing,
                              icon: Icon(Icons.person_outline_rounded, size: 17),
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
                            backgroundColor: Colors.transparent,
                            selectedBackgroundColor: _kAmber,
                            selectedForegroundColor: _kInk,
                            foregroundColor: _kMuted,
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_customerMode == _CustomerMode.walkIn)
                        const _InfoBanner(
                          icon: Icons.verified_user_outlined,
                          message:
                              'Anonymous walk-in sale - no customer info needed',
                        )
                      else if (selectedCustomer != null)
                        _SelectedCustomerCard(
                          customer: selectedCustomer,
                          onClear: () {
                            controller.setCustomer('');
                            _customerSearchController.clear();
                            setState(() => _customerQuery = '');
                          },
                        )
                      else ...[
                        TextField(
                          controller: _customerSearchController,
                          onChanged: (value) =>
                              setState(() => _customerQuery = value),
                          decoration: InputDecoration(
                            hintText: 'Search client by name or phone...',
                            hintStyle: TextStyle(
                              color: _kMuted.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w600,
                            ),
                            prefixIcon:
                                const Icon(Icons.search_rounded, size: 20, color: _kMuted),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            border: _fieldBorder,
                            enabledBorder: _fieldBorder,
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: _kAmber,
                                width: 1.6,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: _kCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _kBorder),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    const Color(0xFF6B5A2A).withValues(alpha: 0.07),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 180),
                            child: ListView.separated(
                              padding: const EdgeInsets.all(6),
                              shrinkWrap: true,
                              itemCount: filteredCustomers.length,
                              separatorBuilder: (_, _) => const Divider(
                                height: 1,
                                indent: 56,
                                color: Color(0xFFF3EDDD),
                              ),
                              itemBuilder: (context, index) {
                                final customer = filteredCustomers[index];
                                final selected =
                                    customer.customerId == cart.customerId;
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  tileColor: selected ? _kWarmTint : null,
                                  leading: customer.imagePath != null
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          child: AppImage.file(
                                            File(customer.imagePath!),
                                            width: 40,
                                            height: 40,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) =>
                                                _CustomerInitials(
                                                    name: customer.name),
                                          ),
                                        )
                                      : _CustomerInitials(name: customer.name),
                                  title: Text(
                                    customer.name,
                                    style: TextStyle(
                                      fontWeight: selected
                                          ? FontWeight.w900
                                          : FontWeight.w700,
                                      color: _kInk,
                                    ),
                                  ),
                                  subtitle: Text(
                                    customer.phone,
                                    style: const TextStyle(
                                      color: _kMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  trailing: selected
                                      ? const Icon(
                                          Icons.check_circle_rounded,
                                          color: _kBronzeText,
                                        )
                                      : null,
                                  onTap: () => controller
                                      .setCustomer(customer.customerId),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      const _SectionHeader(
                        icon: Icons.shopping_bag_outlined,
                        title: 'Items',
                      ),
                      const SizedBox(height: 10),
                      if (cart.items.isEmpty)
                        const _EmptyCart()
                      else
                        Container(
                          decoration: BoxDecoration(
                            color: _kCard,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _kBorder),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6B5A2A)
                                    .withValues(alpha: 0.08),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              for (var index = 0;
                                  index < cart.items.length;
                                  index++) ...[
                                if (index != 0)
                                  const Divider(
                                    height: 1,
                                    indent: 64,
                                    endIndent: 14,
                                    color: Color(0xFFF3EDDD),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  child: _CheckoutItemRow(
                                    item: cart.items[index],
                                    imagePath: productImageMap[
                                        cart.items[index].productId],
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
                                ),
                              ],
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),
                      const _SectionHeader(
                        icon: Icons.percent_rounded,
                        title: 'VAT',
                      ),
                      const SizedBox(height: 10),
                      _PanelCard(
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _kSoftFill,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: _kBorder),
                                  ),
                                  child: SizedBox(
                                    width: 36,
                                    child: TextField(
                                      controller: _vatCustomController,
                                      keyboardType: const TextInputType
                                          .numberWithOptions(
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
                                          color: _kBronzeText,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      ),
                                      style: const TextStyle(
                                        color: _kBronzeText,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                      onChanged: (value) {
                                        final parsed = double.tryParse(value);
                                        if (parsed == null) return;
                                        setState(
                                            () => _vatPercent = parsed);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: _kWarmTint,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _kBorder.withValues(alpha: 0.7),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'VAT Amount (${_vatPercent.toStringAsFixed(_vatPercent % 1 == 0 ? 0 : 1)}%)',
                                    style: const TextStyle(
                                      color: _kMuted,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    money(vatAmount),
                                    style: const TextStyle(
                                      color: _kBronzeText,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const _SectionHeader(
                        icon: Icons.local_offer_outlined,
                        title: 'Discount',
                      ),
                      const SizedBox(height: 10),
                      _PanelCard(
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
                                setState(
                                    () => _discountMode = selection.first);
                              },
                              style: SegmentedButton.styleFrom(
                                backgroundColor: _kWarmTint,
                                selectedBackgroundColor: _kAmber,
                                selectedForegroundColor: _kInk,
                                foregroundColor: _kMuted,
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
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
                                filled: true,
                                fillColor: _kWarmTint,
                                prefixText: _discountMode == _DiscountMode.flat
                                    ? '৳ '
                                    : null,
                                suffixText:
                                    _discountMode == _DiscountMode.percent
                                        ? '%'
                                        : null,
                                prefixStyle: const TextStyle(
                                  color: _kBronzeText,
                                  fontWeight: FontWeight.w800,
                                ),
                                suffixStyle: const TextStyle(
                                  color: _kBronzeText,
                                  fontWeight: FontWeight.w800,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: _kAmber,
                                    width: 1.6,
                                  ),
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const _SectionHeader(
                        icon: Icons.payments_outlined,
                        title: 'Payment Method',
                      ),
                      const SizedBox(height: 10),
                      _PaymentMethodDropdown(
                        selected: _paymentMethod,
                        creditEnabled: _customerMode == _CustomerMode.existing,
                        onChanged: (method) {
                          setState(() => _paymentMethod = method);
                        },
                      ),
                      const SizedBox(height: 20),
                      const _SectionHeader(
                        icon: Icons.receipt_long_outlined,
                        title: 'Summary',
                      ),
                      const SizedBox(height: 10),
                      _PanelCard(
                        child: Column(
                          children: [
                            _TotalLine(label: 'Subtotal', value: money(cart.subtotal)),
                            _TotalLine(label: 'VAT', value: money(vatAmount)),
                            _TotalLine(
                              label: 'Discount',
                              value: '- ${money(discountAmount)}',
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                children: [
                                  Positioned(
                                    right: -34,
                                    top: -48,
                                    child: Container(
                                      width: 130,
                                      height: 130,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white
                                            .withValues(alpha: 0.22),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: -24,
                                    bottom: -56,
                                    child: Container(
                                      width: 120,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.28),
                                          width: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFFFFE36E),
                                          Color(0xFFF3BC00),
                                        ],
                                      ),
                                      border: Border.all(color: _kBorder),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      children: [
                                        const Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'TOTAL',
                                                style: TextStyle(
                                                  color: Color(0xFF6B5210),
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 11,
                                                  letterSpacing: 1,
                                                ),
                                              ),
                                              SizedBox(height: 2),
                                              Text(
                                                'Amount to pay',
                                                style: TextStyle(
                                                  color: Color(0xFF8A6500),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          money(total),
                                          style: const TextStyle(
                                            color: _kInk,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 24,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: (_isCheckingOut ||
                                cart.items.isEmpty ||
                                (_customerMode == _CustomerMode.existing &&
                                    cart.customerId.isEmpty))
                            ? null
                            : const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF40412F), _kInk],
                              ),
                        color: (_isCheckingOut ||
                                cart.items.isEmpty ||
                                (_customerMode == _CustomerMode.existing &&
                                    cart.customerId.isEmpty))
                            ? const Color(0xFFF3E7C3)
                            : null,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: !_isCheckingOut &&
                                cart.items.isNotEmpty &&
                                !(_customerMode == _CustomerMode.existing &&
                                    cart.customerId.isEmpty)
                            ? [
                                BoxShadow(
                                  color: _kInk.withValues(alpha: 0.32),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ]
                            : null,
                      ),
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          disabledForegroundColor:
                              _kMuted.withValues(alpha: 0.6),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: _isCheckingOut ||
                              cart.items.isEmpty ||
                              (_customerMode == _CustomerMode.existing &&
                                  cart.customerId.isEmpty)
                          ? null
                          : () async {
                              setState(() => _isCheckingOut = true);
                              try {
                                final controller =
                                    ref.read(cartProvider.notifier);
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
                        child: Row(
                          children: [
                            if (_isCheckingOut)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Color(0xFFFFFCF0),
                                ),
                              )
                            else
                              const Icon(
                                Icons.shopping_cart_checkout_rounded,
                                color: _kAmber,
                                size: 22,
                              ),
                            const SizedBox(width: 10),
                            Text(
                              _isCheckingOut
                                  ? 'Processing checkout...'
                                  : 'Checkout & invoice',
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFFFFCF0),
                              ),
                            ),
                            const Spacer(),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: !_isCheckingOut
                                  ? Container(
                                      key: const ValueKey('total-chip'),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 13,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.22),
                                        ),
                                      ),
                                      child: Text(
                                        money(total),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: _kAmberLight,
                                        ),
                                      ),
                                    )
                                  : const SizedBox(key: ValueKey('spacer')),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
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

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFEFEF8), _kCard],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B5A2A).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _kSoftFill,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kBorder.withValues(alpha: 0.8)),
          ),
          child: Icon(icon, color: _kBronzeText, size: 17),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: _kMuted,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
              fontSize: 12.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kWarmTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _kSoftFill,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: _kBronzeText, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _kBronzeText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedCustomerCard extends StatelessWidget {
  const _SelectedCustomerCard({required this.customer, required this.onClear});

  final Customer customer;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kAmber.withValues(alpha: 0.65), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: _kAmber.withValues(alpha: 0.14),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          customer.imagePath != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: AppImage.file(
                    File(customer.imagePath!),
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        _CustomerInitials(name: customer.name),
                  ),
                )
              : _CustomerInitials(name: customer.name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: _kInk,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  customer.phone,
                  style: const TextStyle(
                    color: _kMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.check_circle_rounded,
            color: _kBronzeText,
            size: 22,
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(
              foregroundColor: _kBronzeText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Change',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        imagePath != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AppImage.file(
                  File(imagePath!),
                  width: 46,
                  height: 46,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _defaultIcon(),
                ),
              )
            : _defaultIcon(),
        const SizedBox(width: 12),
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
                  color: _kInk,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${money(item.unitPrice)} x ${_formatQuantity(item.qty)}',
                style: const TextStyle(
                  color: _kMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              money(item.unitPrice * item.qty),
              style: const TextStyle(
                color: _kInk,
                fontWeight: FontWeight.w900,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StepperButton(
                  icon: Icons.remove_rounded,
                  onTap: onMinus,
                  emphasized: false,
                ),
                SizedBox(
                  width: 30,
                  child: Text(
                    _formatQuantity(item.qty),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: _kInk,
                      fontSize: 14,
                    ),
                  ),
                ),
                _StepperButton(
                  icon: Icons.add_rounded,
                  onTap: onPlus,
                  emphasized: true,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(width: 2),
        IconButton(
          onPressed: onDelete,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: Color(0xFFEF4444),
            size: 19,
          ),
        ),
      ],
    );
  }

  Widget _defaultIcon() => Container(
    width: 46,
    height: 46,
    decoration: BoxDecoration(
      color: _kSoftFill,
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Icon(
      Icons.shopping_bag_rounded,
      color: _kBronzeText,
      size: 22,
    ),
  );
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.onTap,
    required this.emphasized,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: emphasized ? _kAmber : _kWarmTint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: BorderSide(color: emphasized ? _kBorder : _kBorder.withValues(alpha: 0.8)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(
            icon,
            size: 17,
            color: emphasized ? _kInk : _kBronzeText,
          ),
        ),
      ),
    );
  }
}

class _CustomerInitials extends StatelessWidget {
  const _CustomerInitials({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: _kSoftFill,
      child: Text(
        _initials(name),
        style: const TextStyle(
          color: _kBronzeText,
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_kAmber, _kAmberLight],
                )
              : null,
          color: selected ? null : _kCard,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? _kBorder : _kBorder),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _kAmber.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? _kInk : _kMuted,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _PaymentOption {
  const _PaymentOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
}

const _paymentOptions = <PaymentMethod, _PaymentOption>{
  PaymentMethod.cash: _PaymentOption(
    label: 'Cash',
    subtitle: 'Pay instantly in cash',
    icon: Icons.payments_rounded,
    color: Color(0xFFB45309),
  ),
  PaymentMethod.bkash: _PaymentOption(
    label: 'bKash',
    subtitle: 'Pay via bKash mobile wallet',
    icon: Icons.phone_android_rounded,
    color: Color(0xFFE2136E),
  ),
  PaymentMethod.nagad: _PaymentOption(
    label: 'Nagad',
    subtitle: 'Pay via Nagad mobile wallet',
    icon: Icons.account_balance_wallet_rounded,
    color: Color(0xFFF6921E),
  ),
  PaymentMethod.credit: _PaymentOption(
    label: 'Credit',
    subtitle: "Add to the customer's due balance",
    icon: Icons.credit_card_rounded,
    color: Color(0xFF0F766E),
  ),
  PaymentMethod.bank: _PaymentOption(
    label: 'Bank',
    subtitle: 'Pay via bank transfer',
    icon: Icons.account_balance_rounded,
    color: Color(0xFF0F766E),
  ),
  PaymentMethod.other: _PaymentOption(
    label: 'Other',
    subtitle: 'Any other payment method',
    icon: Icons.more_horiz_rounded,
    color: _kMuted,
  ),
};

class _PaymentMethodDropdown extends StatelessWidget {
  const _PaymentMethodDropdown({
    required this.selected,
    required this.creditEnabled,
    required this.onChanged,
  });

  final PaymentMethod selected;
  final bool creditEnabled;
  final ValueChanged<PaymentMethod> onChanged;

  void _openSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _PaymentMethodSheet(
        selected: selected,
        creditEnabled: creditEnabled,
        onSelected: (method) {
          Navigator.of(sheetContext).pop();
          onChanged(method);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final option = _paymentOptions[selected]!;
    final locked = !creditEnabled && selected == PaymentMethod.credit;
    final color = locked ? const Color(0xFFB9AE93) : option.color;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openSheet(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _kBorder),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6B5A2A).withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(option.icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _kInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      locked
                          ? 'Select a customer to use credit'
                          : option.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _kMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_kAmber, _kAmberLight],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: _kAmber.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _kInk,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentMethodSheet extends StatelessWidget {
  const _PaymentMethodSheet({
    required this.selected,
    required this.creditEnabled,
    required this.onSelected,
  });

  final PaymentMethod selected;
  final bool creditEnabled;
  final ValueChanged<PaymentMethod> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.35],
          colors: [Color(0xFFFFF3CE), _kPage],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4.5,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_kAmber, _kAmberLight],
                ),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Column(
                children: [
                  Text(
                    'Select Payment Method',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _kInk,
                      letterSpacing: -0.4,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Choose how the customer will pay',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _kMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                children: [
                  for (final method in PaymentMethod.values) ...[
                    _PaymentOptionRow(
                      method: method,
                      selected: method == selected,
                      enabled:
                          method != PaymentMethod.credit || creditEnabled,
                      onTap: () => onSelected(method),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kMuted,
                    side: const BorderSide(color: _kBorder),
                    backgroundColor: _kCard,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentOptionRow extends StatelessWidget {
  const _PaymentOptionRow({
    required this.method,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final PaymentMethod method;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final option = _paymentOptions[method]!;
    final color = enabled ? option.color : const Color(0xFFB9AE93);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? _kWarmTint : _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? _kAmber.withValues(alpha: 0.7)
              : _kBorder,
          width: selected ? 1.4 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: _kAmber.withValues(alpha: 0.22),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(option.icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _kInk,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        enabled
                            ? option.subtitle
                            : 'Select a customer to use credit',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _kMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (!enabled)
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: Color(0xFFB9AE93),
                  )
                else if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: _kBronzeText,
                    size: 22,
                  )
                else
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _kBorder,
                        width: 1.6,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TotalLine extends StatelessWidget {
  const _TotalLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: _kMuted,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: _kInk,
              fontWeight: FontWeight.w800,
              fontSize: 14,
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kWarmTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_kAmber, _kAmberLight],
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.shopping_cart_outlined,
              color: _kInk,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Select products to start a sale',
              style: TextStyle(
                color: _kBronzeText,
                fontWeight: FontWeight.w800,
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
