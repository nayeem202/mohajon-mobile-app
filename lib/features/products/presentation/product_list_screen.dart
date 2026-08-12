import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/product.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/nav_bar/nav_bar_aware_fab_location.dart';
import '../providers/product_providers.dart';
import 'product_form_screen.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';

enum _StockFilter { all, low, out }

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  late final TextEditingController _searchController;
  _StockFilter _filter = _StockFilter.all;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final searchQuery = ref.watch(productSearchQueryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5EF),
      body: SafeArea(
        child: productsAsync.when(
          data: (items) {
            final filteredBySearch = ref.watch(filteredProductsProvider);
            final visibleProducts = _applyFilter(filteredBySearch);
    final totalValue = items.fold<double>(
      0,
      (sum, product) =>
          sum + (product.stockQty * product.purchasePrice),
    );
            final lowStockCount = items
                .where((product) => product.isLowStock)
                .length;
            final outStockCount = items
                .where((product) => product.stockQty <= 0)
                .length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              children: [
                 const _StockTopBar(),
                const SizedBox(height: 16),
                _StockStats(
                  totalProducts: items.length,
                  stockValue: totalValue,
                  lowStockCount: lowStockCount,
                  outStockCount: outStockCount,
                ),
                if (_showSearch) ...[
                  const SizedBox(height: 16),
                  _SearchAndFilters(
                    controller: _searchController,
                    searchQuery: searchQuery,
                    selectedFilter: _filter,
                    onSearchChanged: (value) =>
                        ref.read(productSearchQueryProvider.notifier).state =
                            value,
                    onClearSearch: () {
                      _searchController.clear();
                      ref.read(productSearchQueryProvider.notifier).state = '';
                    },
                    onFilterChanged: (filter) => setState(() => _filter = filter),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      'All Products (${visibleProducts.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF101828),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (items.isEmpty)
                  const EmptyState(
                    message: 'Add products to start selling.',
                    icon: Icons.inventory_2_outlined,
                  )
                else if (visibleProducts.isEmpty)
                  const EmptyState(
                    message: 'No products match your search.',
                    icon: Icons.search_off_rounded,
                  )
                else
                  _InventoryList(products: visibleProducts),
              ],
            );
          },
          error: (error, _) => EmptyState(message: error.toString()),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'search',
            onPressed: () {
              setState(() => _showSearch = !_showSearch);
              if (!_showSearch) {
                _searchController.clear();
                ref.read(productSearchQueryProvider.notifier).state = '';
              }
            },
            backgroundColor: const Color(0xFFF97316),
            foregroundColor: Colors.white,
            elevation: 4,
            shape: const CircleBorder(),
            child: Icon(_showSearch ? Icons.search_off_rounded : Icons.search_rounded, size: 24),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'add',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ProductFormScreen())),
            backgroundColor: const Color(0xFFF97316),
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            child: const Icon(Icons.add_rounded, size: 24),
          ),
        ],
      ),
      floatingActionButtonLocation: const NavBarAwareFabLocation(),
    );
  }

  List<Product> _applyFilter(List<Product> products) {
    return switch (_filter) {
      _StockFilter.all => products,
      _StockFilter.low =>
        products.where((product) => product.isLowStock).toList(),
      _StockFilter.out =>
        products.where((product) => product.stockQty <= 0).toList(),
    };
  }
}

class _StockTopBar extends StatelessWidget {
  const _StockTopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFFE98300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.storefront_rounded,
            color: Colors.white,
            size: 17,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Stock',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF101828),
            ),
          ),
        ),
        const NotificationBell(),
        const SizedBox(width: 14),
        const ShopAvatar(radius: 17, backgroundColor: Color(0xFFFCE7C8), textColor: Color(0xFF8A5A11)),
      ],
    );
  }
}

class _StockStats extends StatelessWidget {
  const _StockStats({
    required this.totalProducts,
    required this.stockValue,
    required this.lowStockCount,
    required this.outStockCount,
  });

  final int totalProducts;
  final double stockValue;
  final int lowStockCount;
  final int outStockCount;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _StockStatSpec(
        icon: Icons.inventory_2_rounded,
        label: 'Total Products',
        value: '$totalProducts',
        subtext: 'All products',
        color: const Color(0xFF0F766E),
        background: const Color(0xFFE4F6F1),
      ),
      _StockStatSpec(
        icon: Icons.account_balance_wallet_rounded,
        label: 'Stock Value',
        value: money(stockValue),
        subtext: 'Inventory worth',
        color: const Color(0xFF047857),
        background: const Color(0xFFE9F8F1),
      ),
      _StockStatSpec(
        icon: Icons.warning_amber_rounded,
        label: 'Low Stock',
        value: '$lowStockCount',
        subtext: 'Restock soon',
        color: const Color(0xFFEA580C),
        background: const Color(0xFFFFF4E5),
      ),
      _StockStatSpec(
        icon: Icons.remove_circle_outline_rounded,
        label: 'Out of Stock',
        value: '$outStockCount',
        subtext: 'Unavailable',
        color: const Color(0xFFEF4444),
        background: const Color(0xFFFEF1F1),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSingleColumn = constraints.maxWidth < 320;
        final cardWidth = isSingleColumn
            ? constraints.maxWidth
            : (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final card in cards)
              SizedBox(width: cardWidth, child: _StockStatCard(spec: card)),
          ],
        );
      },
    );
  }
}

class _StockStatSpec {
  const _StockStatSpec({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtext,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final String label;
  final String value;
  final String subtext;
  final Color color;
  final Color background;
}

class _StockStatCard extends StatelessWidget {
  const _StockStatCard({required this.spec});

  final _StockStatSpec spec;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 130,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [spec.background, Colors.white],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: spec.color.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: spec.color.withValues(alpha: 0.09),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: spec.color.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(spec.icon, color: spec.color, size: 16),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: spec.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    spec.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: spec.color,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              spec.value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 20,
                color: colors.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            spec.subtext,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.controller,
    required this.searchQuery,
    required this.selectedFilter,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onFilterChanged,
  });

  final TextEditingController controller;
  final String searchQuery;
  final _StockFilter selectedFilter;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<_StockFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE9DECF)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 46,
            child: TextField(
              controller: controller,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: searchQuery.isEmpty
                    ? null
                    : IconButton(
                        onPressed: onClearSearch,
                        icon: const Icon(Icons.clear_rounded),
                      ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'All Products',
                  selected: selectedFilter == _StockFilter.all,
                  onTap: () => onFilterChanged(_StockFilter.all),
                ),
                _FilterChip(
                  label: 'Low Stock',
                  selected: selectedFilter == _StockFilter.low,
                  onTap: () => onFilterChanged(_StockFilter.low),
                ),
                _FilterChip(
                  label: 'Out of Stock',
                  selected: selectedFilter == _StockFilter.out,
                  onTap: () => onFilterChanged(_StockFilter.out),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF97316) : const Color(0xFFF8F1E6),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF101828),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _InventoryList extends StatelessWidget {
  const _InventoryList({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < products.length; index++) ...[
          if (index != 0) const SizedBox(height: 10),
          _InventoryRow(product: products[index]),
        ],
      ],
    );
  }
}

class _InventoryRow extends StatelessWidget {
  const _InventoryRow({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final isOut = product.stockQty <= 0;
    final isLow = product.isLowStock && !isOut;
    final statusColor = isOut
        ? const Color(0xFFEF4444)
        : isLow
        ? const Color(0xFFEA580C)
        : const Color(0xFF16A34A);
    final statusText = isOut
        ? '0 out of stock'
        : '${_quantity(product.stockQty)} in stock';

    final leading = product.imagePath != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(product.imagePath!),
              width: 42,
              height: 42,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _defaultLeading(),
            ),
          )
        : _defaultLeading();

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          product.nameEn,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF101828),
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          product.category.isEmpty ? 'General' : product.category,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF98A2B3),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    final trailingBlock = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          money(product.sellingPrice),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF101828),
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          statusText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: statusColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 340;

        return Material(
          color: const Color(0xFFFDF7EF),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProductFormScreen(product: product),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFDF7EF),
                border: Border.all(color: const Color(0xFFE9DECF)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            leading,
                            const SizedBox(width: 10),
                            Expanded(child: titleBlock),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: trailingBlock,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        leading,
                        const SizedBox(width: 12),
                        Expanded(child: titleBlock),
                        const SizedBox(width: 10),
                        trailingBlock,
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _defaultLeading() => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: const Color(0xFFFFE3B8),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Icon(
      Icons.inventory_2_rounded,
      color: Color(0xFFF97316),
      size: 20,
    ),
  );
}

String _quantity(int value) {
  return value.toString();
}
