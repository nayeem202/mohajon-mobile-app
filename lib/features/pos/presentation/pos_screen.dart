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
import '../../../core/widgets/async_action_state.dart';
import '../../customers/providers/customer_providers.dart';
import '../../products/providers/product_providers.dart';
import '../../profile/presentation/profile_overview_screen.dart';
import '../providers/cart_provider.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen>
    with AsyncActionState<PosScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _selectedCategory = 'All Products';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider).value ?? const <Product>[];
    final customers = ref.watch(customersProvider).value ?? const <Customer>[];
    final cart = ref.watch(cartProvider);
    final cartController = ref.read(cartProvider.notifier);
    final categories = _categories(products);
    final visibleProducts = _filteredProducts(products);

    final posTheme = Theme.of(context).copyWith(
      inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE9E1D8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE9E1D8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE98300), width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFE98300),
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );

    return withLoadingOverlay(
      Theme(
        data: posTheme,
        child: Scaffold(
          backgroundColor: const Color(0xFFF8F5EF),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TopBar(onAvatarTap: _openProfile),
                      const SizedBox(height: 14),
                      _SearchBar(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _query = value),
                      ),
                      const SizedBox(height: 12),
                      _CategoryStrip(
                        categories: categories,
                        selected: _selectedCategory,
                        onSelected: (value) =>
                            setState(() => _selectedCategory = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _ProductGrid(
                      products: visibleProducts,
                      totalProducts: products.length,
                      enabled: !isBusy,
                      onProductTap: cartController.addProduct,
                    ),
                  ),
                ),
                if (cart.items.isNotEmpty)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: _CheckoutBar(
                        itemCount: cart.items.length,
                        total: cart.total,
                        onTap: isBusy
                            ? null
                            : () => _openCheckoutSheet(customers),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      label: 'Processing sale...',
    );
  }

  List<Product> _filteredProducts(List<Product> products) {
    final query = _query.trim().toLowerCase();
    return products.where((product) {
      final matchesQuery = query.isEmpty ||
          product.nameEn.toLowerCase().contains(query) ||
          product.nameBn.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query) ||
          product.barcode.toLowerCase().contains(query);
      final matchesCategory = _selectedCategory == 'All Products' ||
          product.category == _selectedCategory;
      return matchesQuery && matchesCategory;
    }).toList();
  }

  List<String> _categories(List<Product> products) {
    final categories = <String>{};
    for (final product in products) {
      final category = product.category.trim();
      if (category.isNotEmpty) categories.add(category);
    }
    final sorted = categories.toList()..sort();
    return ['All Products', ...sorted];
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileOverviewScreen()),
    );
  }

  void _openCheckoutSheet(List<Customer> customers) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: MediaQuery.sizeOf(sheetContext).width >= 900 ? 0.90 : 0.94,
          child: _CheckoutSheet(customers: customers),
        );
      },
    );
  }

}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onAvatarTap});

  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFE98300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.storefront_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'New Sale',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF101828),
            ),
          ),
        ),
        const NotificationBell(),
        const SizedBox(width: 14),
        ShopAvatar(radius: 18, backgroundColor: const Color(0xFFF6E0C8), textColor: const Color(0xFFB45309), onTap: onAvatarTap),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: const InputDecoration(
        hintText: 'Search products...',
        prefixIcon: Icon(Icons.search_rounded, size: 20),
      ),
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < categories.length; index++) ...[
            _CategoryChip(
              label: categories[index],
              selected: selected == categories[index],
              onTap: () => onSelected(categories[index]),
            ),
            if (index != categories.length - 1) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFF8A00) : const Color(0xFFF1EAE0),
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

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({
    required this.products,
    required this.totalProducts,
    required this.enabled,
    required this.onProductTap,
  });

  final List<Product> products;
  final int totalProducts;
  final bool enabled;
  final ValueChanged<Product> onProductTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9E1D8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B1F17).withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.inventory_2_rounded,
                  color: colors.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Products',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    Text(
                      '$totalProducts products available',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF667085),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (products.isEmpty)
            const Expanded(child: _CatalogEmptyState())
          else
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.66,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return _ProductCard(
                    product: product,
                    enabled: enabled && product.stockQty > 0,
                    onTap: () => onProductTap(product),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.enabled,
    required this.onTap,
  });

  final Product product;
  final bool enabled;
  final VoidCallback onTap;

  Widget _categoryIcon(Color accent) => Align(
    alignment: Alignment.center,
    child: Icon(
      _iconForCategory(product.category),
      size: 32,
      color: accent,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = _accentForCategory(product.category);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F1E7),
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    if (product.imagePath != null)
                      Image.file(
                        File(product.imagePath!),
                        width: double.infinity,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _categoryIcon(accent),
                      )
                    else
                      _categoryIcon(accent),
                    if (!enabled)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.62),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Text(
                              'Out of stock',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF667085),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                product.nameEn,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF7A2E00),
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                product.category.isNotEmpty ? product.category : 'General',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFB48258),
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      money(product.sellingPrice),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF101828),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: enabled ? onTap : null,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF8A00),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({
    required this.itemCount,
    required this.total,
    required this.onTap,
  });

  final int itemCount;
  final double total;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFF8A00),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF8A00).withValues(alpha: 0.28),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.shopping_cart_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$itemCount items',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    money(total),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const Text(
                'Checkout',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckoutSheet extends ConsumerStatefulWidget {
  const _CheckoutSheet({required this.customers});

  final List<Customer> customers;

  @override
  ConsumerState<_CheckoutSheet> createState() => _CheckoutSheetState();
}

enum _CustomerMode { walkIn, existing }
enum _DiscountMode { flat, percent }

class _CheckoutSheetState extends ConsumerState<_CheckoutSheet> {
  final _discountController = TextEditingController(text: '0');
  final _vatCustomController = TextEditingController(text: '5');
  final _customerSearchController = TextEditingController();

  _CustomerMode _customerMode = _CustomerMode.walkIn;
  _DiscountMode _discountMode = _DiscountMode.flat;
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  double _vatPercent = 5;
  String _customerQuery = '';

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
    final colors = Theme.of(context).colorScheme;
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

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE7D7C3),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
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
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
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
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFFCE2C8),
                                child: Text(
                                  _initials(customer.name),
                                  style: const TextStyle(
                                    color: Color(0xFFB45309),
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
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
                  _SectionTitle(title: 'VAT / TAX'),
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
                            SizedBox(
                              width: 64,
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
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 10,
                                  ),
                                  suffixText: '%',
                                ),
                                onChanged: (value) {
                                  final parsed = double.tryParse(value);
                                  if (parsed == null) return;
                                  setState(() => _vatPercent = parsed);
                                },
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
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: cart.items.isEmpty || (_customerMode == _CustomerMode.existing && cart.customerId.isEmpty)
                          ? null
                          : () async {
                              final controller = ref.read(cartProvider.notifier);
                              controller.setVatPercent(_vatPercent);
                              controller.setDiscount(discountAmount);
                              controller.setPaymentMethod(_paymentMethod);
                              controller.setPaidAmount(_paymentMethod == PaymentMethod.credit ? 0 : total.toDouble());
                              if (_customerMode == _CustomerMode.walkIn) {
                                controller.setCustomer('');
                              }
                              try {
                                final sale = await controller.checkout();
                                if (mounted) {
                                  Navigator.of(context).pop();
                                  final bytes =
                                      await InvoiceService().buildSaleInvoice(
                                    sale,
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
                              }
                            },
                      icon: const Icon(Icons.shopping_cart_checkout_rounded),
                      label: const Text('Checkout & invoice'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
  });

  final SaleItem item;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
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
        ),
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
        IconButton(
          onPressed: onPlus,
          icon: const Icon(Icons.add_rounded),
        ),
        IconButton(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
        ),
      ],
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

class _CatalogEmptyState extends StatelessWidget {
  const _CatalogEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFCF6ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9D8BD)),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            color: Color(0xFFFF8A00),
            size: 28,
          ),
          SizedBox(height: 8),
          Text(
            'No matching products',
            style: TextStyle(
              color: Color(0xFF9A5A1B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

Color _accentForCategory(String category) {
  switch (category.toLowerCase()) {
    case 'grocery':
      return const Color(0xFFF97316);
    case 'beverages':
      return const Color(0xFFEA580C);
    case 'personal care':
      return const Color(0xFFB45309);
    case 'vegetables':
      return const Color(0xFFDC2626);
    case 'health':
      return const Color(0xFFF59E0B);
    case 'rice':
      return const Color(0xFFD97706);
    default:
      return const Color(0xFFE98300);
  }
}

IconData _iconForCategory(String category) {
  switch (category.toLowerCase()) {
    case 'grocery':
      return Icons.local_grocery_store_rounded;
    case 'beverages':
      return Icons.local_drink_rounded;
    case 'personal care':
      return Icons.spa_rounded;
    case 'vegetables':
      return Icons.eco_rounded;
    case 'health':
      return Icons.health_and_safety_rounded;
    case 'rice':
      return Icons.rice_bowl_rounded;
    default:
      return Icons.inventory_2_rounded;
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
