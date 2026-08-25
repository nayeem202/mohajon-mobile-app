import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/product.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/async_action_state.dart';
import '../../../core/widgets/app_image.dart';
import '../../customers/providers/customer_providers.dart';
import '../../products/providers/product_providers.dart';
import '../../profile/presentation/profile_overview_screen.dart';
import '../providers/cart_provider.dart';
import 'checkout_screen.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';

const _kAmber = Color(0xFFFFC800);
const _kAmberLight = Color(0xFFFFD83D);
const _kAmberSoft = Color(0xFFFFF0A6);
const _kInk = Color(0xFF2F3028);
const _kMuted = Color(0xFF77735F);
const _kCard = Color(0xFFFFFDF7);
const _kBorder = Color(0xFFEADFAE);
const _kSoftFill = Color(0xFFFFF4BF);
const _kBronzeText = Color(0xFF8A6500);

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
        hintStyle: TextStyle(
          color: _kMuted.withValues(alpha: 0.75),
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _kAmber, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _kAmber,
          foregroundColor: _kInk,
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
          backgroundColor: Colors.transparent,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.16, 0.34, 1.0],
                colors: [
                  _kAmber,
                  _kAmberLight,
                  _kAmberSoft,
                  Color(0xFFFFFCF0),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
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
                              : () => _openCheckoutScreen(customers),
                        ),
                      ),
                    ),
                ],
              ),
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

  void _openCheckoutScreen(List<Customer> customers) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(customers: customers),
      ),
    );
  }

}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onAvatarTap});

  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_kAmber, Color(0xFFFFE36E)],
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: _kAmber.withValues(alpha: 0.32),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.storefront_rounded,
            color: _kInk,
            size: 17,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'New Sale',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _kInk,
            ),
          ),
        ),
        const NotificationBell(),
        const SizedBox(width: 14),
        ShopAvatar(
          radius: 17,
          backgroundColor: const Color(0xFFFFFDF7),
          textColor: _kInk,
          onTap: onAvatarTap,
        ),
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
        prefixIcon: Icon(Icons.search_rounded, size: 20, color: _kMuted),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
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
          border: Border.all(color: _kBorder),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _kAmber.withValues(alpha: 0.38),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ]
              : [
                  BoxShadow(
                    color: _kInk.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
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

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({
    required this.products,
    required this.enabled,
    required this.onProductTap,
  });

  final List<Product> products;
  final bool enabled;
  final ValueChanged<Product> onProductTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kCard,
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
      child: products.isEmpty
          ? const _CatalogEmptyState()
          : GridView.builder(
              padding: EdgeInsets.zero,
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
    final accent = _accentForCategory(product.category);
    return Container(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder.withValues(alpha: 0.85)),
        boxShadow: [
          BoxShadow(
            color: _kInk.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 80,
                decoration: BoxDecoration(
                  color: _kSoftFill,
                  borderRadius: BorderRadius.circular(11),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    if (product.imagePath != null)
                      AppImage.file(
                        File(product.imagePath!),
                        width: double.infinity,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _categoryIcon(accent),
                      )
                    else
                      _categoryIcon(accent),
                    if (!enabled)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.66),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Center(
                            child: Text(
                              'Out of stock',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _kMuted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              Text(
                product.nameEn,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _kInk,
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
                  color: _kMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
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
                        color: _kInk,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _AddToCartButton(onTap: enabled ? onTap : null),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddToCartButton extends StatelessWidget {
  const _AddToCartButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_kAmber, _kAmberLight],
          ),
          shape: BoxShape.circle,
          border: Border.all(color: _kBorder),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const Icon(
            Icons.add_rounded,
            color: _kInk,
            size: 17,
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
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_kAmber, _kAmberLight],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _kBorder),
            boxShadow: [
              BoxShadow(
                color: _kAmber.withValues(alpha: 0.42),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.shopping_cart_outlined,
                  color: _kInk,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$itemCount items',
                    style: const TextStyle(
                      color: _kInk,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    money(total),
                    style: const TextStyle(
                      color: _kBronzeText,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: _kInk,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: _kInk.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Checkout',
                      style: TextStyle(
                        color: Color(0xFFFFFCF0),
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Color(0xFFFFC800),
                      size: 16,
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
}

class _CatalogEmptyState extends StatelessWidget {
  const _CatalogEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6D5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            color: _kBronzeText,
            size: 30,
          ),
          SizedBox(height: 8),
          Text(
            'No matching products',
            style: TextStyle(
              color: _kMuted,
              fontWeight: FontWeight.w800,
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
