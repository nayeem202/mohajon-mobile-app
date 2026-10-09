import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/product.dart';
import '../../../core/models/purchase.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/action_button.dart';
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
    final l10n = AppLocalizations.of(context);
    final products = ref.watch(productsProvider).value ?? [];
    final purchases = ref.watch(purchasesProvider).value ?? [];
    return withLoadingOverlay(
      Theme(
        data: MohajonWarm.theme(Theme.of(context)),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: Text(l10n.t('purchase'))),
          body: DecoratedBox(
            decoration: const BoxDecoration(gradient: MohajonWarm.pageGradient),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: MohajonWarm.card.withValues(alpha: .94),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: MohajonWarm.goldBorder),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 18,
                        offset: Offset(0, 7),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: MohajonWarm.tintYellow,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(
                              Icons.shopping_bag_rounded,
                              color: MohajonWarm.goldText,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.t('purchaseEntryTitle'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        initialValue: _productId,
                        decoration: InputDecoration(
                          labelText: l10n.t('product'),
                          prefixIcon: const Icon(Icons.inventory_2_rounded),
                        ),
                        items: products
                            .map(
                              (product) => DropdownMenuItem(
                                value: product.productId,
                                child: Text(product.nameEn),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _productId = value),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _qty,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: l10n.t('purchaseQuantity'),
                          prefixIcon: const Icon(Icons.numbers_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _cost,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: l10n.t('unitCost'),
                          prefixIcon: const Icon(Icons.sell_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _paid,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: l10n.t('paidAmount'),
                          prefixIcon: const Icon(Icons.payments_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ActionButton(
                        onPressed: _productId == null
                            ? null
                            : () => _addPurchase(products),
                        isBusy: isBusy,
                        icon: Icons.add_rounded,
                        label: l10n.t('addPurchase'),
                        busyLabel: l10n.t('addingPurchase'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  l10n.t('purchaseHistory'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                if (purchases.isEmpty)
                  _PurchaseEmptyState(message: l10n.t('noPurchases'))
                else
                  for (final purchase in purchases)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: MohajonWarm.card.withValues(alpha: .94),
                        borderRadius: BorderRadius.circular(19),
                        border: Border.all(color: MohajonWarm.goldBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: MohajonWarm.tintOrange,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.local_shipping_rounded,
                              color: MohajonWarm.orange,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  purchase.items
                                      .map((item) => item.name)
                                      .join(', '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  purchase.createdAt
                                      .toLocal()
                                      .toString()
                                      .split('.')
                                      .first,
                                  style: const TextStyle(
                                    color: MohajonWarm.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            money(purchase.dueAmount),
                            style: TextStyle(
                              color: purchase.dueAmount > 0
                                  ? MohajonWarm.red
                                  : MohajonWarm.green,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
      label: l10n.t('savingPurchaseEntry'),
    );
  }

  Future<void> _addPurchase(List<Product> products) async {
    await runBusyAction(() async {
      final product = products.firstWhere(
        (item) => item.productId == _productId,
      );
      await ref
          .read(purchaseServiceProvider)
          .addPurchase(
            supplierId: 'default-supplier',
            paidAmount: double.tryParse(_paid.text) ?? 0,
            items: [
              PurchaseItem(
                productId: product.productId,
                name: product.nameEn,
                qty: double.tryParse(_qty.text) ?? 0,
                unitCost: double.tryParse(_cost.text) ?? product.purchasePrice,
                batchNumber: product.batchNumber,
                expiryDate: product.expiryDate,
              ),
            ],
          );
      _qty.clear();
      _cost.clear();
      _paid.clear();
    });
  }
}

class _PurchaseEmptyState extends StatelessWidget {
  const _PurchaseEmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: MohajonWarm.card.withValues(alpha: .9),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: MohajonWarm.goldBorder),
    ),
    child: Column(
      children: [
        const Icon(
          Icons.receipt_long_rounded,
          color: MohajonWarm.goldText,
          size: 30,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: const TextStyle(
            color: MohajonWarm.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
