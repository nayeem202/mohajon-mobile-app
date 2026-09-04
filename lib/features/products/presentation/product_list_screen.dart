import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../core/utils/app_error.dart';

import '../../../core/models/product.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/nav_bar/nav_bar_aware_fab_location.dart';
import '../providers/product_providers.dart';
import '../services/barcode_label_service.dart';
import 'product_form_screen.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';
import '../../staff/models/menu_codes.dart';
import '../../staff/providers/staff_providers.dart';
import '../../../core/app/app_providers.dart';

final GlobalKey tourAddProductKey = GlobalKey();

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
    final l10n = AppLocalizations.of(context);
    final productsAsync = ref.watch(productsProvider);
    final searchQuery = ref.watch(productSearchQueryProvider);
    final grantedMenus = ref.watch(myMenuCodesProvider).value;
    final session = ref.watch(authStateProvider).value;
    final isOwner = session?.roles.any(
          (role) => role.toUpperCase() == 'OWNER' || role.toUpperCase() == 'ADMIN',
        ) ?? false;
    final canAddProduct = hasMenuAccess(
      grantedMenus,
      MenuCodes.addProduct,
      isOwner: isOwner,
    );

    return Theme(
      data: MohajonWarm.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: MohajonWarm.pageGradient),
          child: SafeArea(
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

                return RefreshIndicator(
                  color: MohajonWarm.goldText,
                  onRefresh: () async {
                    await ref.read(productsProvider.future);
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 96),
                    children: [
                      const _StockTopBar(),
                      const SizedBox(height: 18),
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
                            ref.read(productSearchQueryProvider.notifier).state =
                                '';
                          },
                          onFilterChanged: (filter) =>
                              setState(() => _filter = filter),
                        ),
                      ],
                      const SizedBox(height: 18),
                      _SectionTitle(count: visibleProducts.length),
                      const SizedBox(height: 12),
                      if (items.isEmpty)
                        EmptyState(
                          message: l10n.t('addProductsToStart'),
                          icon: Icons.inventory_2_outlined,
                        )
                      else if (visibleProducts.isEmpty)
                        EmptyState(
                          message: l10n.t('noProductsMatch'),
                          icon: Icons.search_off_rounded,
                        )
                      else
                        _InventoryList(products: visibleProducts),
                    ],
                  ),
                );
              },
              error: (error, _) => EmptyState(
                  message: friendlyErrorMessage(error,
                      fallback: l10n.t('couldNotLoadProducts')),
                ),
              loading: () => const Center(
                child: CircularProgressIndicator(color: MohajonWarm.primary),
              ),
            ),
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
              child: Icon(
                _showSearch ? Icons.search_off_rounded : Icons.search_rounded,
                size: 22,
              ),
            ),
            const SizedBox(height: 8),
            if (canAddProduct)
              KeyedSubtree(
                key: tourAddProductKey,
                child: FloatingActionButton(
                  heroTag: 'add',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProductFormScreen()),
                  ),
                  child: const Icon(Icons.add_rounded, size: 26),
                ),
              ),
          ],
        ),
        floatingActionButtonLocation: const NavBarAwareFabLocation(),
      ),
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
    final l10n = AppLocalizations.of(context);
    return IconTheme(
      data: const IconThemeData(color: MohajonWarm.ink),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [MohajonWarm.primary, MohajonWarm.primaryPale],
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: MohajonWarm.primary.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              color: MohajonWarm.ink,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('stock'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: MohajonWarm.ink,
                  ),
                ),
                Text(
                  l10n.t('productsInventory'),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF77735F),
                  ),
                ),
              ],
            ),
          ),
          const NotificationBell(),
          const SizedBox(width: 14),
          const ShopAvatar(
            radius: 17,
            backgroundColor: Color(0xFFFFFDF7),
            textColor: MohajonWarm.ink,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.t('allProducts'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
              color: MohajonWarm.ink,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: MohajonWarm.primary.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: MohajonWarm.primary.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            '$count ${l10n.t('items')}',
            style: const TextStyle(
              color: Color(0xFF5D4A00),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
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
    final l10n = AppLocalizations.of(context);
    final cards = [
      _StatSpec(
        icon: Icons.inventory_2_rounded,
        label: l10n.t('totalProducts'),
        value: '$totalProducts',
        subtext: l10n.t('allProductsShort'),
        color: MohajonWarm.goldText,
        background: MohajonWarm.tintYellow,
      ),
      _StatSpec(
        icon: Icons.account_balance_wallet_rounded,
        label: l10n.t('stockValue'),
        value: money(stockValue),
        subtext: l10n.t('inventoryWorth'),
        color: MohajonWarm.green,
        background: MohajonWarm.tintGreen,
      ),
      _StatSpec(
        icon: Icons.warning_amber_rounded,
        label: l10n.t('lowStockStat'),
        value: '$lowStockCount',
        subtext: l10n.t('restockSoon'),
        color: MohajonWarm.orange,
        background: MohajonWarm.tintOrange,
      ),
      _StatSpec(
        icon: Icons.remove_circle_outline_rounded,
        label: l10n.t('outOfStock'),
        value: '$outStockCount',
        subtext: l10n.t('unavailable'),
        color: MohajonWarm.red,
        background: MohajonWarm.tintRed,
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
              SizedBox(width: cardWidth, child: _StatCard(spec: card)),
          ],
        );
      },
    );
  }
}

class _StatSpec {
  const _StatSpec({
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

/// Matches the Home screen stat card styling.
class _StatCard extends StatelessWidget {
  const _StatCard({required this.spec});

  final _StatSpec spec;

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
          colors: [spec.background, MohajonWarm.card],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MohajonWarm.goldBorder),
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
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MohajonWarm.card,
        border: Border.all(color: MohajonWarm.goldBorder),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: MohajonWarm.ink.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 46,
            child: TextField(
              controller: controller,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: l10n.t('searchProductsHint'),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: MohajonWarm.muted,
                ),
                suffixIcon: searchQuery.isEmpty
                    ? null
                    : IconButton(
                        onPressed: onClearSearch,
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: MohajonWarm.muted,
                        ),
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
                  label: l10n.t('allProducts'),
                  selected: selectedFilter == _StockFilter.all,
                  onTap: () => onFilterChanged(_StockFilter.all),
                ),
                _FilterChip(
                  label: l10n.t('lowStockStat'),
                  selected: selectedFilter == _StockFilter.low,
                  onTap: () => onFilterChanged(_StockFilter.low),
                ),
                _FilterChip(
                  label: l10n.t('outOfStock'),
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
      child: Material(
        color: selected ? MohajonWarm.primary : Colors.white,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? MohajonWarm.primary.withValues(alpha: 0.45)
                    : MohajonWarm.goldBorder,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFF5D4A00) : MohajonWarm.muted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
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
    final l10n = AppLocalizations.of(context);
    final isOut = product.stockQty <= 0;
    final isLow = product.isLowStock && !isOut;
    final statusColor = isOut
        ? MohajonWarm.red
        : isLow
        ? MohajonWarm.orange
        : MohajonWarm.green;
    final statusBg = isOut
        ? MohajonWarm.tintRed
        : isLow
        ? MohajonWarm.tintOrange
        : MohajonWarm.tintGreen;
    final statusText = isOut
        ? l10n.t('outOfStockNow')
        : l10n.tP('qtyInStock', {'qty': _quantity(product.stockQty)});

    final leading = product.imagePath != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: AppImage.file(
              File(product.imagePath!),
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _defaultLeading(),
            ),
          )
        : _defaultLeading();

    return Material(
      color: MohajonWarm.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductFormScreen(product: product),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: MohajonWarm.goldBorder),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: MohajonWarm.ink.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 340;
              final titleBlock = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.nameEn,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: MohajonWarm.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    product.category.isEmpty ? l10n.t('general') : product.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: MohajonWarm.muted,
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
                      color: MohajonWarm.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              );

              final hasBarcode = product.barcode.trim().isNotEmpty;
              final trailing = hasBarcode
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        trailingBlock,
                        const SizedBox(width: 2),
                        IconButton(
                          tooltip: 'Print barcode label',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.print_outlined,
                            size: 19,
                            color: MohajonWarm.muted,
                          ),
                          onPressed: () => _printLabel(context, product),
                        ),
                      ],
                    )
                  : trailingBlock;

              if (compact) {
                return Column(
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
                    Align(alignment: Alignment.centerRight, child: trailing),
                  ],
                );
              }

              return Row(
                children: [
                  leading,
                  const SizedBox(width: 12),
                  Expanded(child: titleBlock),
                  const SizedBox(width: 10),
                  trailing,
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _defaultLeading() => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFE9CF), Color(0xFFFCD9AE)],
      ),
      borderRadius: BorderRadius.circular(13),
    ),
    child: const Icon(
      Icons.inventory_2_rounded,
      color: Color(0xFFE98300),
      size: 20,
    ),
  );

  Future<void> _printLabel(BuildContext context, Product product) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Printing.layoutPdf(
        name: 'barcode-${product.barcode}',
        onLayout: (format) => BarcodeLabelService().buildLabels(
          [
            BarcodeLabel(
              code: product.barcode,
              name: product.nameEn,
              price: product.sellingPrice,
            ),
          ],
          format: format,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to print barcode: $e'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }
}

String _quantity(int value) {
  return value.toString();
}
