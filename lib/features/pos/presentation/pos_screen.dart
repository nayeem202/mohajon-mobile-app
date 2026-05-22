import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/services/invoice_service.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/async_action_state.dart';
import '../../customers/providers/customer_providers.dart';
import '../../products/providers/product_providers.dart';
import '../providers/cart_provider.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen>
    with AsyncActionState<PosScreen> {
  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final products = ref.watch(productsProvider).value ?? [];
    final customers = ref.watch(customersProvider).value ?? [];
    final cart = ref.watch(cartProvider);
    final cartController = ref.read(cartProvider.notifier);
    return withLoadingOverlay(
      Scaffold(
        appBar: AppBar(title: const Text('POS')),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final productGridHeight = (constraints.maxHeight * 0.42).clamp(
              180.0,
              360.0,
            ).toDouble();

            return Column(
              children: [
                SizedBox(
                  height: productGridHeight,
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 170,
                          childAspectRatio: 0.92,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return _ProductTile(
                        name: product.nameEn,
                        stock: product.stockQty,
                        price: money(product.sellingPrice),
                        lowStock: product.isLowStock,
                        enabled: product.stockQty > 0 && !isBusy,
                        onTap: () => cartController.addProduct(product),
                      );
                    },
                  ),
                ),
                Divider(
                  height: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: cart.customerId.isEmpty
                            ? null
                            : cart.customerId,
                        decoration: const InputDecoration(
                          labelText: 'Customer',
                        ),
                        items: customers
                            .map(
                              (customer) => DropdownMenuItem(
                                value: customer.customerId,
                                child: Text(customer.name),
                              ),
                            )
                            .toList(),
                        onChanged: isBusy
                            ? null
                            : (value) => cartController.setCustomer(value ?? ''),
                      ),
                      const SizedBox(height: 12),
                      for (final item in cart.items)
                        Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            title: Text(item.name),
                            subtitle: Text(
                              '${item.qty} x ${money(item.unitPrice)}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: isBusy
                                      ? null
                                      : () => cartController.setQty(
                                          item.productId,
                                          item.qty - 1,
                                        ),
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                  ),
                                ),
                                Text(money(item.lineTotal)),
                                IconButton(
                                  onPressed: isBusy
                                      ? null
                                      : () => cartController.setQty(
                                          item.productId,
                                          item.qty + 1,
                                        ),
                                  icon: const Icon(Icons.add_circle_outline),
                                ),
                              ],
                            ),
                          ),
                        ),
                      TextField(
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: 'Discount'),
                        onChanged: isBusy
                            ? null
                            : (value) => cartController.setDiscount(
                                double.tryParse(value) ?? 0,
                              ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Paid amount',
                        ),
                        onChanged: isBusy
                            ? null
                            : (value) => cartController.setPaidAmount(
                                double.tryParse(value) ?? 0,
                              ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.receipt_long_rounded,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Cart summary',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              _totalRow('Subtotal', money(cart.subtotal)),
                              _totalRow('Discount', money(cart.discount)),
                              _totalRow('Total', money(cart.total)),
                              _totalRow('Due', money(cart.due)),
                            ],
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: cart.items.isEmpty || isBusy
                            ? null
                            : _checkout,
                        icon: const Icon(Icons.receipt_long),
                        label: const Text('Checkout & invoice'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      label: 'Processing sale...',
    );
  }

  Widget _totalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text(value)],
      ),
    );
  }

  Future<void> _checkout() async {
    final cart = ref.read(cartProvider);
    if (cart.due > 0 && cart.customerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a customer before saving a due sale.'),
        ),
      );
      return;
    }

    await runBusyAction(() async {
      final sale = await ref.read(cartProvider.notifier).checkout();
      final bytes = await InvoiceService().buildSaleInvoice(sale);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'invoice-${sale.saleId}.pdf',
      );
    });
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.name,
    required this.stock,
    required this.price,
    required this.lowStock,
    required this.enabled,
    required this.onTap,
  });

  final String name;
  final double stock;
  final String price;
  final bool lowStock;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final stockLabel = stock % 1 == 0 ? stock.toStringAsFixed(0) : '$stock';
    final stockColor = !enabled
        ? colorScheme.error
        : (lowStock ? colorScheme.secondary : colorScheme.primary);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled ? onTap : null,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.surface,
                colorScheme.primary.withValues(alpha: 0.045),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.22),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(
                        enabled
                            ? Icons.add_shopping_cart_rounded
                            : Icons.remove_shopping_cart_rounded,
                        size: 18,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: stockColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          enabled ? 'Stock $stockLabel' : 'Out',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: stockColor,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      name,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: enabled
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    price,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.secondary,
                      fontWeight: FontWeight.w900,
                    ),
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
