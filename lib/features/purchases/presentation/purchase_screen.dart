import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/product.dart';
import '../../../core/models/purchase.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/async_action_state.dart';
import '../../products/providers/product_providers.dart';
import '../providers/purchase_providers.dart';

class PurchaseScreen extends ConsumerStatefulWidget {
  const PurchaseScreen({super.key});

  @override
  ConsumerState<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends ConsumerState<PurchaseScreen>
    with AsyncActionState<PurchaseScreen> {
  String? _productId;
  final _qty = TextEditingController();
  final _cost = TextEditingController();
  final _paid = TextEditingController();

  @override
  void dispose() {
    _qty.dispose();
    _cost.dispose();
    _paid.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider).value ?? [];
    final purchases = ref.watch(purchasesProvider).value ?? [];
    return withLoadingOverlay(
      Scaffold(
        appBar: AppBar(title: const Text('Purchase')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _productId,
                      decoration: const InputDecoration(labelText: 'Product'),
                      items: products
                          .map(
                            (product) => DropdownMenuItem(
                              value: product.productId,
                              child: Text(product.nameEn),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _productId = value),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _qty,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Quantity'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _cost,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Unit cost'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _paid,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Paid amount',
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _productId == null || isBusy
                          ? null
                          : () => _addPurchase(products),
                      icon: const Icon(Icons.add),
                      label: const Text('Add purchase'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (final purchase in purchases)
              Card(
                child: ListTile(
                  title: Text(
                    purchase.items.map((item) => item.name).join(', '),
                  ),
                  subtitle: Text(
                    purchase.createdAt.toLocal().toString().split('.').first,
                  ),
                  trailing: Text(money(purchase.dueAmount)),
                ),
              ),
          ],
        ),
      ),
      label: 'Saving purchase...',
    );
  }

  Future<void> _addPurchase(List<Product> products) async {
    await runBusyAction(() async {
      final product = products.firstWhere((item) => item.productId == _productId);
      await ref.read(purchaseServiceProvider).addPurchase(
        supplierId: 'default-supplier',
        paidAmount: double.tryParse(_paid.text) ?? 0,
        items: [
          PurchaseItem(
            productId: product.productId,
            name: product.nameEn,
            qty: double.tryParse(_qty.text) ?? 0,
            unitCost: double.tryParse(_cost.text) ?? product.purchasePrice,
          ),
        ],
      );
      _qty.clear();
      _cost.clear();
      _paid.clear();
    });
  }
}
