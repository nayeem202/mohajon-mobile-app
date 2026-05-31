import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/product.dart';
import '../../../core/models/shop_profile.dart';
import '../../../core/widgets/async_action_state.dart';
import '../../customers/providers/customer_providers.dart';
import '../../products/providers/product_providers.dart';
import '../../settings/providers/shop_profile_providers.dart';
import '../models/receipt.dart';
import '../providers/receipt_providers.dart';
import '../services/receipt_pdf_service.dart';
import 'receipt_preview_screen.dart';

class ReceiptGeneratorScreen extends ConsumerStatefulWidget {
  const ReceiptGeneratorScreen({super.key});

  @override
  ConsumerState<ReceiptGeneratorScreen> createState() =>
      _ReceiptGeneratorScreenState();
}

class _ReceiptGeneratorScreenState
    extends ConsumerState<ReceiptGeneratorScreen>
    with AsyncActionState<ReceiptGeneratorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pdfService = ReceiptPdfService();
  final _shopNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _profileSeedShopId;
  int _profileSeedVersion = -1;

  @override
  void dispose() {
    _shopNameController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final receipt = ref.watch(receiptViewModelProvider);
    final viewModel = ref.read(receiptViewModelProvider.notifier);
    final shopId = ref.watch(shopIdProvider);
    final products = ref.watch(productsProvider).value ?? const <Product>[];
    final customers = ref.watch(customersProvider).value ?? const <Customer>[];
    final profile = ref.watch(shopProfileProvider).value;
    final dateText = DateFormat('MMM dd, yyyy').format(receipt.date);
    final profileComplete = _hasCompleteShopProfile(profile);

    _seedProfile(shopId, profile);

    if (profileComplete &&
        receipt.companyName.isEmpty &&
        receipt.companyAddress.isEmpty &&
        receipt.companyPhone.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        viewModel.setCompanyProfile(
          companyName: profile!.shopName,
          companyAddress: profile.location,
          companyPhone: profile.phoneNumber,
        );
      });
    }

    return withLoadingOverlay(
      Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: isBusy
              ? null
              : () => _startCheckout(
                    receipt: receipt,
                    profile: profile,
                    profileComplete: profileComplete,
                  ),
          icon: const Icon(Icons.shopping_bag_outlined),
          label: const Text('Checkout'),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
            children: [
              if (!profileComplete)
                _SectionCard(
                  title: 'Company Information',
                  icon: Icons.storefront_rounded,
                  children: [
                    _profileTextField(
                      controller: _shopNameController,
                      label: 'Shop Name',
                    ),
                    _profileTextField(
                      controller: _locationController,
                      label: 'Location',
                    ),
                    _profileTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      keyboardType: TextInputType.phone,
                    ),
                    const Text(
                      'This information will be saved once when you complete the first checkout.',
                    ),
                  ],
                ),
              _SectionCard(
                title: 'Customer Information',
                icon: Icons.person_outline_rounded,
                children: [
                  DropdownButtonFormField<String>(
                    key: ValueKey('customer-${receipt.customerId}'),
                    initialValue:
                        receipt.customerId.isEmpty ? null : receipt.customerId,
                    decoration: const InputDecoration(
                      labelText: 'Customer Name',
                    ),
                    items: [
                      for (final customer in customers)
                        DropdownMenuItem(
                          value: customer.customerId,
                          child: Text(customer.name),
                        ),
                    ],
                    onChanged: (value) {
                      final customer = customers.cast<Customer?>().firstWhere(
                            (item) => item?.customerId == value,
                            orElse: () => null,
                          );
                      viewModel.selectCustomer(customer);
                    },
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Select a customer' : null,
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'Phone Number'),
                    child: Text(
                      receipt.customerPhone.isEmpty
                          ? 'Customer phone will show here'
                          : receipt.customerPhone,
                    ),
                  ),
                ],
              ),
              _SectionCard(
                title: 'Checkout Details',
                icon: Icons.receipt_long_rounded,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: receipt.paymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'Payment Method',
                    ),
                    items: [
                      for (final method in receiptPaymentMethods)
                        DropdownMenuItem(value: method, child: Text(method)),
                    ],
                    onChanged: (value) {
                      if (value != null) viewModel.updatePaymentMethod(value);
                    },
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'Receipt Number'),
                    child: Text(receipt.receiptNumber),
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date'),
                    child: Text(dateText),
                  ),
                ],
              ),
              _SectionCard(
                title: 'Products',
                icon: Icons.playlist_add_check_rounded,
                children: [
                  for (var index = 0; index < receipt.items.length; index++)
                    _ReceiptItemRow(
                      key: ValueKey(receipt.items[index].id),
                      item: receipt.items[index],
                      index: index,
                      products: products,
                      canDelete: receipt.items.length > 1,
                      onProductChanged: viewModel.updateItemProduct,
                      onQuantityChanged: viewModel.updateItemQuantity,
                      onDelete: viewModel.removeItem,
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: viewModel.addItem,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Product'),
                  ),
                ],
              ),
              _SectionCard(
                title: 'Amounts',
                icon: Icons.calculate_outlined,
                children: [
                  _PercentControl(
                    label: 'Discount Percentage',
                    value: receipt.discountPercent,
                    onChanged: viewModel.updateDiscountPercent,
                    enabled:
                        receipt.discountType == ReceiptDiscountType.percentage,
                  ),
                  const SizedBox(height: 12),
                  _DiscountModeCard(
                    receipt: receipt,
                    onDiscountTypeChanged: viewModel.updateDiscountType,
                    onFixedAmountChanged: viewModel.updateDiscountFixedAmount,
                  ),
                  const SizedBox(height: 12),
                  _PercentControl(
                    label: 'Tax Rate',
                    value: receipt.taxPercent,
                    onChanged: viewModel.updateTaxPercent,
                  ),
                  const SizedBox(height: 14),
                  _TotalsPanel(receipt: receipt),
                ],
              ),
            ],
          ),
        ),
      ),
      label: 'Processing checkout...',
    );
  }

  Widget _profileTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  bool _hasCompleteShopProfile(ShopProfile? profile) {
    return profile != null &&
        profile.shopName.trim().isNotEmpty &&
        profile.location.trim().isNotEmpty &&
        profile.phoneNumber.trim().isNotEmpty;
  }

  void _seedProfile(String shopId, ShopProfile? profile) {
    final version = Object.hash(
      shopId,
      profile?.shopName ?? '',
      profile?.location ?? '',
      profile?.phoneNumber ?? '',
    );
    if (_profileSeedShopId == shopId && _profileSeedVersion == version) return;

    _shopNameController.text = profile?.shopName ?? '';
    _locationController.text = profile?.location ?? '';
    _phoneController.text = profile?.phoneNumber ?? '';
    _profileSeedShopId = shopId;
    _profileSeedVersion = version;
  }

  bool _validateReceipt(Receipt receipt, List<Product> products) {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return false;
    if (receipt.items.isEmpty) {
      _showMessage('Add at least one product');
      return false;
    }

    final totalsByProduct = <String, double>{};
    for (final item in receipt.items) {
      if (item.productId.isEmpty || item.description.trim().isEmpty) {
        _showMessage('Select a product for each item');
        return false;
      }
      if (item.quantity <= 0) {
        _showMessage('Quantity must be greater than zero');
        return false;
      }
      totalsByProduct.update(
        item.productId,
        (value) => value + item.quantity,
        ifAbsent: () => item.quantity,
      );
    }

    for (final entry in totalsByProduct.entries) {
      final product = products.cast<Product?>().firstWhere(
            (item) => item?.productId == entry.key,
            orElse: () => null,
          );
      if (product == null) {
        _showMessage('One selected product is no longer available');
        return false;
      }
      if (entry.value > product.stockQty) {
        _showMessage('Requested quantity is higher than available stock');
        return false;
      }
    }

    return true;
  }

  Future<void> _startCheckout({
    required Receipt receipt,
    required ShopProfile? profile,
    required bool profileComplete,
  }) async {
    try {
      final products = ref.read(productsProvider).value ?? const <Product>[];
      if (!_validateReceipt(receipt, products)) return;

      final preparedReceipt = await _prepareReceiptProfile(
        receipt: receipt,
        profile: profile,
        profileComplete: profileComplete,
      );
      if (preparedReceipt == null || !mounted) return;

      final confirmed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ReceiptPreviewScreen(receipt: preparedReceipt),
        ),
      );
      if (confirmed != true || !mounted) return;

      await runBusyAction(() async {
        await ref.read(receiptCheckoutServiceProvider).checkout(preparedReceipt);
        final file = await _pdfService.saveToDownloads(preparedReceipt);
        ref.read(receiptViewModelProvider.notifier).reset();
        if (!mounted) return;
        _showSavedMessage(file);
      });
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString());
    }
  }

  Future<Receipt?> _prepareReceiptProfile({
    required Receipt receipt,
    required ShopProfile? profile,
    required bool profileComplete,
  }) async {
    if (profileComplete && profile != null) {
      final prepared = receipt.copyWith(
        companyName: profile.shopName,
        companyAddress: profile.location,
        companyPhone: profile.phoneNumber,
      );
      ref.read(receiptViewModelProvider.notifier).setCompanyProfile(
            companyName: profile.shopName,
            companyAddress: profile.location,
            companyPhone: profile.phoneNumber,
          );
      return prepared;
    }

    final shopName = _shopNameController.text.trim();
    final location = _locationController.text.trim();
    final phoneNumber = _phoneController.text.trim();
    if (shopName.isEmpty || location.isEmpty || phoneNumber.isEmpty) {
      _showMessage('Complete company information before checkout');
      return null;
    }

    await ref.read(shopProfileServiceProvider).updateProfile(
          shopName: shopName,
          location: location,
          phoneNumber: phoneNumber,
        );
    ref.read(receiptViewModelProvider.notifier).setCompanyProfile(
          companyName: shopName,
          companyAddress: location,
          companyPhone: phoneNumber,
        );
    return receipt.copyWith(
      companyName: shopName,
      companyAddress: location,
      companyPhone: phoneNumber,
    );
  }

  void _showSavedMessage(File file) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Checkout completed. PDF saved to ${file.path}')),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _ReceiptItemRow extends StatelessWidget {
  const _ReceiptItemRow({
    super.key,
    required this.item,
    required this.index,
    required this.products,
    required this.canDelete,
    required this.onProductChanged,
    required this.onQuantityChanged,
    required this.onDelete,
  });

  final ReceiptItem item;
  final int index;
  final List<Product> products;
  final bool canDelete;
  final void Function(String id, Product? product) onProductChanged;
  final void Function(String id, String quantity) onQuantityChanged;
  final void Function(String id) onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Product ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                if (canDelete)
                  IconButton(
                    onPressed: () => onDelete(item.id),
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            DropdownButtonFormField<String>(
              key: ValueKey('${item.id}-${item.productId}'),
              initialValue: item.productId.isEmpty ? null : item.productId,
              decoration: const InputDecoration(labelText: 'Item Name'),
              items: [
                for (final product in products)
                  DropdownMenuItem(
                    value: product.productId,
                    child: Text(product.nameEn),
                  ),
              ],
              onChanged: (value) {
                final product = products.cast<Product?>().firstWhere(
                      (item) => item?.productId == value,
                      orElse: () => null,
                    );
                onProductChanged(item.id, product);
              },
              validator: (value) =>
                  value == null || value.isEmpty ? 'Select a product' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: ValueKey('qty-${item.id}-${item.quantity}'),
              initialValue: item.quantity.toStringAsFixed(
                item.quantity % 1 == 0 ? 0 : 2,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
              ],
              decoration: const InputDecoration(labelText: 'Quantity'),
              onChanged: (value) => onQuantityChanged(item.id, value),
              validator: (value) {
                final quantity = double.tryParse(value ?? '');
                if (quantity == null || quantity <= 0) {
                  return 'Enter a valid quantity';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Unit Price'),
              child: Text(item.price.toStringAsFixed(2)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _PercentControl extends StatelessWidget {
  const _PercentControl({
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label (${value.toStringAsFixed(0)}%)'),
        Slider(
          value: value,
          min: 0,
          max: 100,
          divisions: 100,
          label: value.toStringAsFixed(0),
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }
}

class _DiscountModeCard extends StatefulWidget {
  const _DiscountModeCard({
    required this.receipt,
    required this.onDiscountTypeChanged,
    required this.onFixedAmountChanged,
  });

  final Receipt receipt;
  final ValueChanged<ReceiptDiscountType> onDiscountTypeChanged;
  final ValueChanged<double> onFixedAmountChanged;

  @override
  State<_DiscountModeCard> createState() => _DiscountModeCardState();
}

class _DiscountModeCardState extends State<_DiscountModeCard> {
  late final TextEditingController _fixedAmountController;

  @override
  void initState() {
    super.initState();
    _fixedAmountController = TextEditingController();
    _syncController();
  }

  @override
  void didUpdateWidget(covariant _DiscountModeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.receipt.discountFixedAmount !=
            widget.receipt.discountFixedAmount ||
        oldWidget.receipt.discountType != widget.receipt.discountType) {
      _syncController();
    }
  }

  @override
  void dispose() {
    _fixedAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final discountType = widget.receipt.discountType;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Discount Type'),
        const SizedBox(height: 10),
        SegmentedButton<ReceiptDiscountType>(
          segments: const [
            ButtonSegment<ReceiptDiscountType>(
              value: ReceiptDiscountType.percentage,
              label: Text('Percentage'),
            ),
            ButtonSegment<ReceiptDiscountType>(
              value: ReceiptDiscountType.fixedAmount,
              label: Text('Fixed Amount'),
            ),
          ],
          selected: {discountType},
          onSelectionChanged: (value) {
            widget.onDiscountTypeChanged(value.first);
          },
        ),
        if (discountType == ReceiptDiscountType.fixedAmount) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _fixedAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Discount Amount',
              hintText: 'Enter fixed discount amount',
              helperText:
                  'Applied as a fixed market discount before tax calculation.',
            ),
            onChanged: (value) {
              widget.onFixedAmountChanged(double.tryParse(value) ?? 0);
            },
          ),
        ],
      ],
    );
  }

  void _syncController() {
    final value = widget.receipt.discountFixedAmount;
    _fixedAmountController.text = value == 0 ? '' : value.toStringAsFixed(
      value == value.roundToDouble() ? 0 : 2,
    );
  }
}

class _TotalsPanel extends StatelessWidget {
  const _TotalsPanel({required this.receipt});

  final Receipt receipt;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _totalRow('Subtotal', receiptMoney(receipt.subtotal)),
          _totalRow(_discountLabel(receipt), '-${receiptMoney(receipt.discountAmount)}'),
          _totalRow('Tax', receiptMoney(receipt.taxAmount)),
          const Divider(height: 20),
          _totalRow(
            'Total',
            receiptMoney(receipt.total),
            emphasize: true,
          ),
        ],
      ),
    );
  }

  String _discountLabel(Receipt receipt) {
    return switch (receipt.discountType) {
      ReceiptDiscountType.percentage =>
        'Discount (${receipt.discountPercent.toStringAsFixed(0)}%)',
      ReceiptDiscountType.fixedAmount => 'Discount (Fixed Amount)',
    };
  }

  Widget _totalRow(String label, String value, {bool emphasize = false}) {
    final style = TextStyle(
      fontWeight: emphasize ? FontWeight.w900 : FontWeight.w500,
      fontSize: emphasize ? 16 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}
