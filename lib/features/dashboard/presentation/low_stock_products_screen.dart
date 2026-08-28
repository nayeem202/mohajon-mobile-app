import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/product.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
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

  Widget _productIcon() => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF0C2), Color(0xFFFCE3B4)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE98300).withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              color: Color(0xFFE98300),
              size: 18,
            ),
          ),
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Low stock products'),
        backgroundColor: MohajonWarm.primary,
        foregroundColor: MohajonWarm.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: MohajonWarm.primary,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      floatingActionButton: Material(
        shape: const CircleBorder(),
        elevation: 4,
        color: MohajonWarm.primary,
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
              color: MohajonWarm.ink,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: MohajonWarm.pageGradient),
        child: widget.products.isEmpty
            ? const Center(
                child: EmptyState(
                  message: 'No low stock products right now.',
                  icon: Icons.warning_amber_rounded,
                ),
              )
            : Column(
                children: [
                  if (_showSearch) ...[
                    _SearchPanel(
                      controller: _searchController,
                      query: _searchQuery,
                      onSearchChanged: (value) =>
                          setState(() => _searchQuery = value),
                      onClearSearch: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
                  ],
                  _SummaryCard(count: widget.products.length),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      itemCount: filtered.isEmpty ? 1 : filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        if (filtered.isEmpty) {
                          return const Center(
                            child: EmptyState(
                              message: 'No products match your search.',
                              icon: Icons.search_off_rounded,
                            ),
                          );
                        }
                        final product = filtered[index];
                        final isOut = product.stockQty <= 0;
                        final statusColor =
                            isOut ? MohajonWarm.red : MohajonWarm.orange;
                        final level = (product.stockQty /
                                (product.lowStockAlert * 2))
                            .clamp(0.0, 1.0)
                            .toDouble();

                        return Card(
                          elevation: 0,
                          margin: EdgeInsets.zero,
                          color: MohajonWarm.card,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: MohajonWarm.goldBorder),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    ProductFormScreen(product: product),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  product.imagePath != null
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          child: AppImage.file(
                                            File(product.imagePath!),
                                            width: 56,
                                            height: 56,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) =>
                                                _productIcon(),
                                          ),
                                        )
                                      : _productIcon(),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product.displayName(localeCode),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: MohajonWarm.ink,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [
                                            _ProductChip(product.category
                                                    .isEmpty
                                                ? 'General'
                                                : product.category),
                                            _ProductChip(
                                              'Stock ${product.stockQty}',
                                              tint: statusColor
                                                  .withValues(alpha: 0.12),
                                              textColor: statusColor,
                                            ),
                                            _ProductChip(
                                                'Alert ${product.lowStockAlert}'),
                                          ],
                                        ),
                                        const SizedBox(height: 9),
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          child: Container(
                                            height: 5,
                                            color: MohajonWarm.tintYellow,
                                            child: FractionallySizedBox(
                                              alignment: Alignment.centerLeft,
                                              widthFactor: level,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      MohajonWarm.orange,
                                                      statusColor,
                                                    ],
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          999),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        money(product.sellingPrice),
                                        style: const TextStyle(
                                          color: MohajonWarm.ink,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color: statusColor,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              isOut ? 'Out' : 'Low',
                                              style: TextStyle(
                                                color: statusColor,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ],
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
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF0C2), Color(0xFFFCE3B4)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MohajonWarm.goldBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: MohajonWarm.orange,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count products running low',
                  style: const TextStyle(
                    color: MohajonWarm.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Restock soon to avoid missing sales.',
                  style: const TextStyle(
                    color: MohajonWarm.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
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
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: MohajonWarm.goldBorder),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2F3028).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SizedBox(
        height: 46,
        child: TextField(
          controller: controller,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search product name, category...',
            prefixIcon:
                Icon(Icons.search_rounded, size: 20, color: MohajonWarm.primary),
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
  const _ProductChip(this.label, {this.tint, this.textColor});

  final String label;
  final Color? tint;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: tint ?? MohajonWarm.tintYellow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor ?? MohajonWarm.muted,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
