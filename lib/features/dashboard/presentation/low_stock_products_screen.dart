import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/models/product.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/app_image.dart';
import '../../products/presentation/product_form_screen.dart';

class LowStockProductsScreen extends StatefulWidget {
  const LowStockProductsScreen({super.key, required this.products});

  final List<Product> products;

  @override
  State<LowStockProductsScreen> createState() => _LowStockProductsScreenState();
}

class _LowStockProductsScreenState extends State<LowStockProductsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showSearch = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _productIcon(BuildContext context) => Container(
    width: 52,
    height: 52,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Icon(
      Icons.inventory_2_rounded,
      color: Theme.of(context).colorScheme.error,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final localeCode = Localizations.localeOf(context).languageCode;
    final query = _searchQuery.trim().toLowerCase();
    final filtered = query.isEmpty
        ? widget.products
        : widget.products
              .where((product) =>
                  product
                      .displayName(localeCode)
                      .toLowerCase()
                      .contains(query) ||
                  product.category.toLowerCase().contains(query))
              .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Low stock products'),
      ),
      floatingActionButton: Material(
        shape: const CircleBorder(),
        elevation: 4,
        color: const Color(0xFFF97316),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) {
                _searchController.clear();
                _searchQuery = '';
              }
            });
          },
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(
              _showSearch ? Icons.search_off_rounded : Icons.search_rounded,
              size: 22,
              color: Colors.white,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: widget.products.isEmpty
          ? const EmptyState(
              message: 'No low stock products right now.',
              icon: Icons.warning_amber_rounded,
            )
          : Column(
              children: [
                if (_showSearch) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _SearchPanel(
                      controller: _searchController,
                      query: _searchQuery,
                      onSearchChanged: (value) =>
                          setState(() => _searchQuery = value),
                      onClearSearch: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
                  ),
                ],
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    itemCount: filtered.isEmpty ? 1 : filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      if (filtered.isEmpty) {
                        return const EmptyState(
                          message: 'No products match your search.',
                          icon: Icons.search_off_rounded,
                        );
                      }
                      final product = filtered[index];
                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ProductFormScreen(product: product),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                product.imagePath != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: AppImage.file(
                                          File(product.imagePath!),
                                          width: 52,
                                          height: 52,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              _productIcon(context),
                                        ),
                                      )
                                    : _productIcon(context),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.displayName(localeCode),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                                fontWeight: FontWeight.w800),
                                      ),
                                      const SizedBox(height: 5),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          _ProductChip(
                                            label: product.category.isEmpty
                                                ? 'General'
                                                : product.category,
                                          ),
                                          _ProductChip(
                                            label: 'Stock ${product.stockQty}',
                                          ),
                                          _ProductChip(
                                            label:
                                                'Alert ${product.lowStockAlert}',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      money(product.sellingPrice),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w900),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Low stock',
                                      style: TextStyle(
                                        color:
                                            Theme.of(context).colorScheme.error,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.controller,
    required this.query,
    required this.onSearchChanged,
    required this.onClearSearch,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE8E4DB)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SizedBox(
        height: 46,
        child: TextField(
          controller: controller,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search product name, category...',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    onPressed: onClearSearch,
                    icon: const Icon(Icons.clear_rounded),
                  ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
      ),
    );
  }
}

class _ProductChip extends StatelessWidget {
  const _ProductChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
