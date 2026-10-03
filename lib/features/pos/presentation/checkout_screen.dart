import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_error.dart';
import '../../../core/utils/snackbar.dart';
import 'package:printing/printing.dart';

import '../../../core/models/customer.dart';
import '../../../core/app/app_providers.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/product.dart';
import '../../../core/models/sale.dart';
import '../../../core/services/invoice_service.dart';
import '../../../core/services/download_export_service.dart';
import '../../../core/services/pdf_doc.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/utils/money.dart';
import '../../products/providers/product_providers.dart';
import '../../customers/providers/customer_providers.dart';
import '../../settings/providers/shop_profile_providers.dart';
import '../providers/cart_provider.dart';
import '../services/whatsapp_service.dart';
import '../services/digital_invoice_service.dart';
import 'widgets/sale_success_sheet.dart';

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
  bool _useLoyaltyReward = false;

  @override
  void initState() {
    super.initState();
    final cart = ref.read(cartProvider);
    if (cart.customerId.isNotEmpty) {
      _customerMode = _CustomerMode.existing;
    }
    // Keep the checkout VAT selection in sync with the cart's default so the
    // on-screen total always matches the sale that actually gets saved.
    _vatPercent = cart.vatPercent;
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
    final l10n = AppLocalizations.of(context);
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
    final loyalty = selectedCustomer == null
        ? null
        : ref.watch(customerLoyaltyProvider(selectedCustomer.customerId));
    final loyaltyOffer = ref.watch(loyaltyOfferProvider);

    final vatAmount = cart.subtotal * (_vatPercent / 100);
    final manualDiscountAmount = _discountAmount(cart.subtotal, vatAmount);
    final loyaltyDiscount = _useLoyaltyReward &&
            loyaltyOffer.enabled &&
            loyalty?.points != null &&
            loyalty!.points >= loyaltyOffer.pointsRequired &&
            cart.subtotal >= loyaltyOffer.minimumPurchase
        ? ((cart.subtotal + vatAmount) * loyaltyOffer.discountPercent / 100)
            .clamp(0, loyaltyOffer.maxDiscount)
            .toDouble()
        : 0.0;
    final discountAmount = (manualDiscountAmount + loyaltyDiscount)
        .clamp(0, cart.subtotal + vatAmount)
        .toDouble();
    final total = (cart.subtotal + vatAmount - discountAmount).clamp(
      0,
      double.infinity,
    );
    final canCheckout =
        !_isCheckingOut &&
        cart.items.isNotEmpty &&
        !(_customerMode == _CustomerMode.existing && cart.customerId.isEmpty);

    return Theme(
      data: MohajonWarm.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: MohajonWarm.pageGradient),
          child: Stack(
            children: [
              Positioned(
                top: -70,
                right: -50,
                child: _glowCircle(190, Colors.white.withValues(alpha: 0.16)),
              ),
              Positioned(
                top: 30,
                right: 96,
                child: _glowCircle(64, Colors.white.withValues(alpha: 0.14)),
              ),
              Positioned(
                top: 110,
                left: -60,
                child: _glowCircle(150, Colors.white.withValues(alpha: 0.10)),
              ),
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 16, 12),
                      child: Row(
                        children: [
                          Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(11),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(11),
                              onTap: _isCheckingOut
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(11),
                                  border: Border.all(color: _kBorder),
                                ),
                                child: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: _kInk,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  MohajonWarm.primary,
                                  MohajonWarm.primaryPale,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: MohajonWarm.primary.withValues(
                                    alpha: 0.28,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.shopping_cart_checkout_rounded,
                              color: _kInk,
                              size: 17,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.t('checkout'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: _kInk,
                                  ),
                                ),
                                Text(
                                  l10n.t('reviewItemsPayment'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10,
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
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: MohajonWarm.primary.withValues(
                                  alpha: 0.22,
                                ),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: MohajonWarm.primary.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                              child: Text(
                                '${cart.items.length} items',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF5D4A00),
                                ),
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
                            _SectionHeader(
                              icon: Icons.person_outline_rounded,
                              title: l10n.t('customer'),
                              iconColor: MohajonWarm.goldText,
                              iconBackground: MohajonWarm.tintYellow,
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
                                segments: [
                                  ButtonSegment(
                                    value: _CustomerMode.walkIn,
                                    icon: const Icon(
                                      Icons.directions_walk_rounded,
                                      size: 17,
                                    ),
                                    label: Text(l10n.t('walkIn')),
                                  ),
                                  ButtonSegment(
                                    value: _CustomerMode.existing,
                                    icon: const Icon(
                                      Icons.person_outline_rounded,
                                      size: 17,
                                    ),
                                    label: Text(l10n.t('existingClient')),
                                  ),
                                ],
                                selected: {_customerMode},
                                onSelectionChanged: (selection) {
                                  final mode = selection.first;
                                  setState(() {
                                    _customerMode = mode;
                                    if (mode == _CustomerMode.walkIn) {
                                      controller.setCustomer('');
                                      if (_paymentMethod ==
                                          PaymentMethod.credit) {
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
                              const _WalkInCustomerNotice()
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
                                  hintText: l10n.t('searchClientHint'),
                                  prefixIcon: const Icon(
                                    Icons.search_rounded,
                                    size: 20,
                                    color: MohajonWarm.muted,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (filteredCustomers.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: _kCard,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: _kBorder),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              MohajonWarm.primary,
                                              MohajonWarm.primaryPale,
                                            ],
                                          ),
                                          borderRadius: BorderRadius.all(
                                            Radius.circular(13),
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.person_add_rounded,
                                          color: _kInk,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              widget.customers.isEmpty
                                                  ? l10n.t('noClientsYet')
                                                  : l10n.t('noClientMatch'),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                                color: _kInk,
                                                fontSize: 13.5,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              widget.customers.isEmpty
                                                  ? l10n.t('noClientsYetHint')
                                                  : l10n.t('tryDifferentName'),
                                              style: const TextStyle(
                                                color: _kMuted,
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                                height: 1.4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Container(
                                decoration: BoxDecoration(
                                  color: _kCard,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: _kBorder),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF6B5A2A,
                                      ).withValues(alpha: 0.07),
                                      blurRadius: 14,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 180,
                                  ),
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
                                          customer.customerId ==
                                          cart.customerId;
                                      return ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 2,
                                            ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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
                                                        name: customer.name,
                                                      ),
                                                ),
                                              )
                                            : _CustomerInitials(
                                                name: customer.name,
                                              ),
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
                                        onTap: () => controller.setCustomer(
                                          customer.customerId,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            _SectionHeader(
                              icon: Icons.shopping_bag_outlined,
                              title: l10n.t('items'),
                              iconColor: MohajonWarm.green,
                              iconBackground: MohajonWarm.tintGreen,
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
                                      color: const Color(
                                        0xFF6B5A2A,
                                      ).withValues(alpha: 0.08),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    for (
                                      var index = 0;
                                      index < cart.items.length;
                                      index++
                                    ) ...[
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
                                          imagePath:
                                              productImageMap[cart
                                                  .items[index]
                                                  .productId],
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
                            _SectionHeader(
                              icon: Icons.percent_rounded,
                              title: l10n.t('vat'),
                              iconColor: MohajonWarm.orange,
                              iconBackground: MohajonWarm.tintOrange,
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
                                        height: 34,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: MohajonWarm.tintYellow,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          border: Border.all(
                                            color:
                                                MohajonWarm.primary.withValues(
                                              alpha: 0.45,
                                            ),
                                          ),
                                        ),
                                        child: SizedBox(
                                          width: 74,
                                          child: Center(
                                            child: TextField(
                                              controller:
                                                  _vatCustomController,
                                              keyboardType: const TextInputType
                                                  .numberWithOptions(
                                                decimal: true,
                                              ),
                                              textAlign: TextAlign.center,
                                              cursorColor:
                                                  MohajonWarm.goldText,
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .allow(
                                                  RegExp(r'[0-9.]'),
                                                ),
                                              ],
                                              decoration: InputDecoration(
                                                filled: false,
                                                isDense: true,
                                                contentPadding:
                                                    EdgeInsets.zero,
                                                border: InputBorder.none,
                                                enabledBorder:
                                                    InputBorder.none,
                                                focusedBorder:
                                                    InputBorder.none,
                                                hintText: l10n.t('custom'),
                                                hintStyle: const TextStyle(
                                                  color: MohajonWarm.muted,
                                                  fontWeight:
                                                      FontWeight.w800,
                                                  fontSize: 11,
                                                ),
                                                suffixText: '%',
                                                suffixStyle: const TextStyle(
                                                  color:
                                                      MohajonWarm.goldText,
                                                  fontWeight:
                                                      FontWeight.w900,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              style: const TextStyle(
                                                color:
                                                    MohajonWarm.goldText,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 13,
                                              ),
                                              onChanged: (value) {
                                                final parsed =
                                                    double.tryParse(
                                                  value,
                                                );
                                                if (parsed == null) return;
                                                setState(
                                                  () => _vatPercent =
                                                      parsed,
                                                );
                                              },
                                            ),
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
                                          l10n.tP('vatAmount', {
                                            'pct':
                                                _vatPercent.toStringAsFixed(_vatPercent % 1 == 0 ? 0 : 1),
                                          }),
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
                            _SectionHeader(
                              icon: Icons.local_offer_outlined,
                              title: l10n.t('discount'),
                              iconColor: MohajonWarm.red,
                              iconBackground: MohajonWarm.tintRed,
                            ),
                            const SizedBox(height: 10),
                            _PanelCard(
                              child: Column(
                                children: [
                                  SegmentedButton<_DiscountMode>(
                                    segments: [
                                      ButtonSegment(
                                        value: _DiscountMode.flat,
                                        label: Text(l10n.t('discountFlat')),
                                      ),
                                      ButtonSegment(
                                        value: _DiscountMode.percent,
                                        label: Text(l10n.t('discountPercent')),
                                      ),
                                    ],
                                    selected: {_discountMode},
                                    onSelectionChanged: (selection) {
                                      setState(
                                        () => _discountMode = selection.first,
                                      );
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
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
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
                                      prefixText:
                                          _discountMode == _DiscountMode.flat
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
                                  if (loyaltyOffer.enabled &&
                                      loyalty?.points != null &&
                                      loyalty!.points >= loyaltyOffer.pointsRequired &&
                                      cart.subtotal >= loyaltyOffer.minimumPurchase) ...[
                                    const SizedBox(height: 8),
                                    SwitchListTile.adaptive(
                                      contentPadding: EdgeInsets.zero,
                                      value: _useLoyaltyReward,
                                      onChanged: (value) => setState(() => _useLoyaltyReward = value),
                                      title: Text(l10n.t('useLoyaltyReward'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                                      subtitle: Text(l10n.t('loyaltyRewardOffer'), style: const TextStyle(fontSize: 11, color: _kMuted)),
                                      secondary: const Icon(Icons.stars_rounded, color: MohajonWarm.goldText),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            _SectionHeader(
                              icon: Icons.payments_outlined,
                              title: l10n.t('paymentMethod'),
                              iconColor: MohajonWarm.goldText,
                              iconBackground: MohajonWarm.tintYellow,
                            ),
                            const SizedBox(height: 10),
                            _PaymentMethodDropdown(
                              selected: _paymentMethod,
                              creditEnabled:
                                  _customerMode == _CustomerMode.existing,
                              onChanged: (method) {
                                setState(() => _paymentMethod = method);
                              },
                            ),
                            const SizedBox(height: 20),
                            _SectionHeader(
                              icon: Icons.receipt_long_outlined,
                              title: l10n.t('summary'),
                              iconColor: MohajonWarm.green,
                              iconBackground: MohajonWarm.tintGreen,
                            ),
                            const SizedBox(height: 10),
                            _PanelCard(
                              child: Column(
                                children: [
                                  _TotalLine(
                                    label: l10n.t('subtotal'),
                                    value: money(cart.subtotal),
                                  ),
                                  _TotalLine(
                                    label: l10n.t('vat'),
                                    value: money(vatAmount),
                                  ),
                                  _TotalLine(
                                    label: l10n.t('discount'),
                                    value: '- ${money(discountAmount)}',
                                  ),
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
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
                                              color: Colors.white.withValues(
                                                alpha: 0.22,
                                              ),
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
                                                color: Colors.white.withValues(
                                                  alpha: 0.28,
                                                ),
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
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: MohajonWarm.primary
                                                    .withValues(alpha: 0.30),
                                                blurRadius: 16,
                                                offset: const Offset(0, 6),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      l10n.t('total').toUpperCase(),
                                                      style: TextStyle(
                                                        color: Color(
                                                          0xFF6B5210,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        fontSize: 11,
                                                        letterSpacing: 1,
                                                      ),
                                                    ),
                                                    SizedBox(height: 2),
                                                    Text(
                                                      l10n.t('amountToPay'),
                                                      style: TextStyle(
                                                        color: Color(
                                                          0xFF8A6500,
                                                        ),
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w700,
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
                    Container(
                      decoration: BoxDecoration(
                        color: MohajonWarm.card,
                        border: const Border(
                          top: BorderSide(color: MohajonWarm.goldBorder),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: MohajonWarm.ink.withValues(alpha: 0.06),
                            blurRadius: 16,
                            offset: const Offset(0, -6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: SafeArea(
                        top: false,
                        minimum: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'TOTAL',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: _kMuted,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      money(total),
                                      maxLines: 1,
                                      style: const TextStyle(
                                        fontSize: 21,
                                        fontWeight: FontWeight.w900,
                                        color: _kInk,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: canCheckout
                                    ? const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          MohajonWarm.primary,
                                          MohajonWarm.primaryPale,
                                        ],
                                      )
                                    : null,
                                color: canCheckout
                                    ? null
                                    : MohajonWarm.tintYellow,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: canCheckout
                                    ? [
                                        BoxShadow(
                                          color: MohajonWarm.primary.withValues(
                                            alpha: 0.38,
                                          ),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  disabledBackgroundColor: Colors.transparent,
                                  disabledForegroundColor: MohajonWarm.muted
                                      .withValues(alpha: 0.55),
                                  elevation: 0,
                                  minimumSize: const Size(64, 54),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: canCheckout
                                    ? () async {
                                        setState(() => _isCheckingOut = true);
                                        final navigator = Navigator.of(context);
                                        final l10n = AppLocalizations.of(context);
                                        try {
                                          final controller = ref.read(
                                            cartProvider.notifier,
                                          );
                                          controller.setVatPercent(_vatPercent);
                                          controller.setDiscount(
                                            discountAmount,
                                          );
                                          controller.setLoyaltyPointsRedeemed(
                                            _useLoyaltyReward ? 100 : 0,
                                          );
                                          controller.setPaymentMethod(
                                            _paymentMethod,
                                          );
                                          controller.setPaidAmount(
                                            _paymentMethod ==
                                                    PaymentMethod.credit
                                                ? 0
                                                : total.toDouble(),
                                          );
                                          if (_customerMode ==
                                              _CustomerMode.walkIn) {
                                            controller.setCustomer('');
                                          }
                                          final sale = await controller
                                              .checkout();
                                          final shopProfile = ref
                                              .read(shopProfileProvider)
                                              .value;
                                          final billMessage = WhatsAppService
                                              .billMessage(
                                            sale: sale,
                                            shopName:
                                                shopProfile?.shopName ?? '',
                                            customerName:
                                                selectedCustomer?.name ?? '',
                                            t: (key) => l10n.t(key),
                                          );
                                          if (context.mounted) {
                                            await showModalBottomSheet<void>(
                                              context: context,
                                              backgroundColor: Colors.transparent,
                                              isScrollControlled: true,
                                              builder: (_) => SaleSuccessSheet(
                                                onPrint: () async {
                                                  final bytes =
                                                      await InvoiceService()
                                                          .buildThermalReceipt(
                                                    sale,
                                                    customerName:
                                                        selectedCustomer
                                                                ?.name ??
                                                            '',
                                                    customerPhone:
                                                        selectedCustomer
                                                                ?.phone ??
                                                            '',
                                                    company: DocCompany
                                                        .fromShop(shopProfile),
                                                  );
                                                  await Printing.layoutPdf(
                                                    name:
                                                        'receipt-${sale.saleId}',
                                                    onLayout: (_) async => bytes,
                                                  );
                                                },
                                                onSave: () async {
                                                  String? path;
                                                  try {
                                                    final bytes = await InvoiceService()
                                                        .buildThermalReceipt(
                                                      sale,
                                                      customerName:
                                                          selectedCustomer
                                                                  ?.name ??
                                                              '',
                                                      customerPhone:
                                                          selectedCustomer
                                                                  ?.phone ??
                                                              '',
                                                      company: DocCompany
                                                          .fromShop(shopProfile),
                                                    );
                                                    path =
                                                        await DownloadExportService()
                                                            .saveFileToDownloads(
                                                      fileName:
                                                          'receipt-${sale.saleId}.pdf',
                                                      mimeType:
                                                          'application/pdf',
                                                      bytes: bytes,
                                                    );
                                                  } catch (_) {
                                                    if (!context.mounted) {
                                                      return;
                                                    }
                                                    showAppSnackBar(
                                                      context,
                                                      l10n.t(
                                                        'receiptSaveFailed',
                                                      ),
                                                      isError: true,
                                                    );
                                                    return;
                                                  }
                                                  if (!context.mounted) {
                                                    return;
                                                  }
                                                  showAppSnackBar(
                                                    context,
                                                    l10n.tP(
                                                      'receiptSavedAt',
                                                      {'path': path ?? 'Download'},
                                                    ),
                                                  );
                                                },
                                                whatsappPhone:
                                                    selectedCustomer?.phone,
                                                whatsappMessage: billMessage,
                                                onDigitalInvoice: () async {
                                                  try {
                                                    final uri = await DigitalInvoiceService(
                                                      ref.read(localDatabaseProvider),
                                                    ).createLink(sale);
                                                    if (!context.mounted) return;
                                                    if (uri == null) {
                                                      showAppSnackBar(context, l10n.t('digitalInvoiceUnavailable'), isError: true);
                                                      return;
                                                    }
                                                    final ok = await WhatsAppService.openChat(
                                                      phone: selectedCustomer?.phone ?? '',
                                                      message: '${l10n.t('digitalInvoiceMessage')}\n$uri',
                                                    );
                                                    if (!ok && context.mounted) {
                                                      showAppSnackBar(context, l10n.t('whatsappFailed'), isError: true);
                                                    }
                                                  } catch (_) {
                                                    if (context.mounted) {
                                                      showAppSnackBar(context, l10n.t('digitalInvoiceUnavailable'), isError: true);
                                                    }
                                                  }
                                                },
                                              ),
                                            );
                                          }
                                          if (context.mounted) navigator.pop();
                                        } catch (error) {
                                          if (context.mounted) {
                                            showAppSnackBar(
                                              context,
                                              friendlyErrorMessage(error),
                                              isError: true,
                                            );
                                          }
                                        } finally {
                                          if (context.mounted) {
                                            setState(
                                              () => _isCheckingOut = false,
                                            );
                                          }
                                        }
                                      } : null,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_isCheckingOut)
                                      const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: MohajonWarm.ink,
                                        ),
                                      )
                                    else
                                      const Icon(
                                        Icons.shopping_cart_checkout_rounded,
                                        color: MohajonWarm.ink,
                                        size: 20,
                                      ),
                                    const SizedBox(width: 9),
                                    Text(
                                      _isCheckingOut
                                          ? l10n.t('processingDots')
                                          : l10n.t('checkout'),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: MohajonWarm.ink,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _glowCircle(double size, Color color) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
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
    required this.iconColor,
    required this.iconBackground,
  });

  final IconData icon;
  final String title;
  final Color iconColor;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(
                color: iconColor.withValues(alpha: 0.18),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _kInk,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _WalkInCustomerNotice extends StatelessWidget {
  const _WalkInCustomerNotice();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: MohajonWarm.tintYellow,
              borderRadius: BorderRadius.all(Radius.circular(13)),
            ),
            child: const Icon(
              Icons.directions_walk_rounded,
              color: _kInk,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('walkIn'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: _kInk,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  l10n.t('walkInHint'),
                  style: const TextStyle(
                    color: _kMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
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
    final l10n = AppLocalizations.of(context);
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
          const Icon(Icons.check_circle_rounded, color: _kBronzeText, size: 22),
          const SizedBox(width: 4),
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(
              foregroundColor: _kBronzeText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              l10n.t('change'),
              style: const TextStyle(fontWeight: FontWeight.w800),
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
      crossAxisAlignment: CrossAxisAlignment.start,
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _kInk,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    money(item.unitPrice * item.qty),
                    style: const TextStyle(
                      color: _kInk,
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5,
                    ),
                  ),
                ],
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
              const SizedBox(height: 10),
              Row(
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
                  const Spacer(),
                  Material(
                    color: MohajonWarm.tintRed,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: onDelete,
                      child: const SizedBox(
                        width: 30,
                        height: 30,
                        child: Icon(
                          Icons.delete_outline_rounded,
                          color: Color(0xFFDC2626),
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
        side: BorderSide(
          color: emphasized ? _kBorder : _kBorder.withValues(alpha: 0.8),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, size: 17, color: emphasized ? _kInk : _kBronzeText),
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

String _paymentLabel(PaymentMethod m, AppLocalizations l10n) {
  switch (m) {
    case PaymentMethod.cash:
      return l10n.t('cash');
    case PaymentMethod.bkash:
      return l10n.t('bkash');
    case PaymentMethod.nagad:
      return l10n.t('nagad');
    case PaymentMethod.credit:
      return l10n.t('credit');
    case PaymentMethod.bank:
      return l10n.t('bank');
    case PaymentMethod.other:
      return l10n.t('other');
  }
}

String _paymentSubtitle(PaymentMethod m, AppLocalizations l10n) {
  switch (m) {
    case PaymentMethod.cash:
      return l10n.t('payCashSub');
    case PaymentMethod.bkash:
      return l10n.t('payBKashSub');
    case PaymentMethod.nagad:
      return l10n.t('payNagadSub');
    case PaymentMethod.credit:
      return l10n.t('payCreditSub');
    case PaymentMethod.bank:
      return l10n.t('payBankSub');
    case PaymentMethod.other:
      return l10n.t('payOtherSub');
  }
}

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
    final l10n = AppLocalizations.of(context);
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
                      _paymentLabel(selected, l10n),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _kInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      locked
                          ? l10n.t('creditLockedHint')
                          : _paymentSubtitle(selected, l10n),
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
    final l10n = AppLocalizations.of(context);
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
                gradient: const LinearGradient(colors: [_kAmber, _kAmberLight]),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Column(
                children: [
                  Text(
                    l10n.t('choosePaymentMethod'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _kInk,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    l10n.t('chooseHowCustomerWillPay'),
                    style: const TextStyle(
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
                      enabled: method != PaymentMethod.credit || creditEnabled,
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
                  child: Text(
                    l10n.t('cancel'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
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
    final l10n = AppLocalizations.of(context);
    final option = _paymentOptions[method]!;
    final color = enabled ? option.color : const Color(0xFFB9AE93);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? _kWarmTint : _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? _kAmber.withValues(alpha: 0.7) : _kBorder,
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
                        _paymentLabel(method, l10n),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _kInk,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        enabled
                            ? _paymentSubtitle(method, l10n)
                            : l10n.t('creditLockedHint'),
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
                      border: Border.all(color: _kBorder, width: 1.6),
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
  const _TotalLine({required this.label, required this.value});

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
            style: const TextStyle(fontWeight: FontWeight.w600, color: _kMuted),
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
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty);
  final initials = parts
      .take(2)
      .map((part) => part.substring(0, 1).toUpperCase())
      .join();
  return initials.isEmpty ? '?' : initials;
}

String _formatQuantity(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}
