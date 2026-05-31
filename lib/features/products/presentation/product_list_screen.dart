import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../providers/product_providers.dart';
import 'product_form_screen.dart';

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  late final TextEditingController _searchController;

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
    final products = ref.watch(productsProvider);
    final searchQuery = ref.watch(productSearchQueryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('products'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ProductFormScreen())),
        icon: const Icon(Icons.add),
        label: Text(l10n.t('addProduct')),
      ),
      body: products.when(
        data: (items) {
          final filteredItems = ref.watch(filteredProductsProvider);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => ref
                      .read(productSearchQueryProvider.notifier)
                      .state = value,
                  decoration: InputDecoration(
                    hintText: 'Search products by name, barcode or category',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: searchQuery.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              ref.read(productSearchQueryProvider.notifier).state = '';
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? const EmptyState(
                        message: 'Add products to start selling.',
                        icon: Icons.inventory_2_outlined,
                      )
                    : filteredItems.isEmpty
                    ? const EmptyState(
                        message: 'No products match your search.',
                        icon: Icons.search_off_rounded,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                        itemCount: filteredItems.length,
                        separatorBuilder: (_, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final product = filteredItems[index];
                          return Card(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ProductFormScreen(product: product),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 54,
                                      height: 54,
                                      decoration: BoxDecoration(
                                        color: product.isLowStock
                                            ? Theme.of(context).colorScheme.error
                                                .withValues(alpha: 0.1)
                                            : Theme.of(context).colorScheme.primary
                                                  .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Icon(
                                        product.isLowStock
                                            ? Icons.warning_amber_rounded
                                            : Icons.inventory_2_rounded,
                                        color: product.isLowStock
                                            ? Theme.of(context).colorScheme.error
                                            : Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.nameEn,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
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
                                              if (product.barcode.isNotEmpty)
                                                _ProductChip(label: product.barcode),
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
                                              .titleMedium
                                              ?.copyWith(fontWeight: FontWeight.w900),
                                        ),
                                        const SizedBox(height: 6),
                                        if (product.isLowStock)
                                          Text(
                                            'Low stock',
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.error,
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
          );
        },
        error: (error, _) => EmptyState(message: error.toString()),
        loading: () => const Center(child: CircularProgressIndicator()),
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
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
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
