import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/product.dart';
import '../../../core/models/purchase.dart';
import '../../../core/models/sale.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/async_action_state.dart';
import '../../../core/widgets/insight_widgets.dart';
import '../../customers/providers/customer_providers.dart';
import '../../expenses/providers/expense_providers.dart';
import '../../products/providers/product_providers.dart';
import '../../branches/providers/branch_providers.dart';
import '../providers/purchase_providers.dart';
import '../models/purchase_order.dart';
import '../services/purchase_order_service.dart';

class PurchasePlannerScreen extends ConsumerStatefulWidget {
  const PurchasePlannerScreen({super.key});

  @override
  ConsumerState<PurchasePlannerScreen> createState() =>
      _PurchasePlannerScreenState();
}

class _PurchasePlannerScreenState extends ConsumerState<PurchasePlannerScreen>
    with AsyncActionState<PurchasePlannerScreen> {
  final _budgetController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(purchasePlannerServiceProvider).syncPending(),
    );
  }

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider).value ?? const <Product>[];
    final sales = ref.watch(salesStreamProvider).value ?? const <Sale>[];
    final purchases = ref.watch(purchasesProvider).value ?? const <Purchase>[];
    final expenses = ref.watch(expensesProvider).value ?? const [];
    final db = ref.read(localDatabaseProvider);
    final suppliers = db.suppliers.valuesForShop(ref.read(shopIdProvider));
    final planner = ref.read(purchasePlannerServiceProvider);
    final recommendations = planner.recommendations(
      products: products,
      sales: sales,
      purchases: purchases,
      suppliers: suppliers,
    );
    final calculatedBudget = planner.cashBudget(sales: sales, expenses: expenses);
    final budget = double.tryParse(_budgetController.text) ?? calculatedBudget;
    final total = recommendations.fold<double>(
      0,
      (sum, item) => sum + item.estimatedTotal,
    );
    final l10n = AppLocalizations.of(context);
    final overBudget = total > budget;

    return withLoadingOverlay(
      PremiumInsightPage(
        title: l10n.t('purchasePlannerTitle'),
        subtitle: l10n.t('featurePurchasePlannerSubtitle'),
        icon: Icons.shopping_cart_checkout_rounded,
        headerTrailing: IconButton(
          tooltip: l10n.t('purchaseRefresh'),
          onPressed: () => planner.syncPending(),
          icon: const Icon(Icons.sync_rounded, color: MohajonWarm.ink, size: 20),
        ),
        children: [
          const SizedBox(height: 18),
          InsightHeroCard(
            icon: Icons.shopping_cart_checkout_rounded,
            accent: recommendations.isEmpty
                ? MohajonWarm.green
                : overBudget
                    ? MohajonWarm.red
                    : MohajonWarm.orange,
            title: l10n.t('purchaseBrief'),
            body: l10n.t('purchaseBriefDesc'),
            trailingValue: money(total),
            trailingLabel: l10n.t('purchaseRecommended'),
            badge: recommendations.isEmpty
                ? l10n.t('purchaseHealthy')
                : '${recommendations.length}',
            badgeAccent: recommendations.isEmpty ? MohajonWarm.green : null,
          ),
          const SizedBox(height: 14),
          InsightMetricGrid(
            tiles: [
              InsightMetricTile(
                label: l10n.t('purchaseCashBudget'),
                value: money(calculatedBudget),
                icon: Icons.account_balance_wallet_rounded,
                accent: MohajonWarm.green,
              ),
              InsightMetricTile(
                label: l10n.t('purchaseRecommended'),
                value: money(total),
                icon: Icons.shopping_cart_rounded,
                accent: overBudget ? MohajonWarm.red : MohajonWarm.orange,
                caption: recommendations.isEmpty
                    ? null
                    : '${recommendations.length}',
              ),
            ],
          ),
          InsightSectionTitle(
            title: l10n.t('purchaseBudget'),
            icon: Icons.tune_rounded,
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: InsightTokens.cardDecoration(),
            child: TextField(
              controller: _budgetController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.t('purchaseBudget'),
                prefixText: '৳ ',
                helperText: l10n.t('purchaseBudgetHint'),
                helperStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: MohajonWarm.muted,
                ),
              ),
            ),
          ),
          StreamBuilder<List<PurchaseOrder>>(
            stream: db.purchaseOrders.watchForShop(ref.read(shopIdProvider)).map((items) {
              final shopId = ref.read(shopIdProvider);
              final branchId = ref.read(currentBranchIdProvider) ?? '$shopId-main';
              return items.where((item) => (item.branchId ?? '$shopId-main') == branchId).toList();
            }),
            builder: (context, snapshot) {
              final orders = snapshot.data ?? const <PurchaseOrder>[];
              if (orders.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InsightSectionTitle(
                    title: l10n.t('purchaseOrders'),
                    icon: Icons.receipt_long_rounded,
                    trailing: InsightBadge(label: '${orders.length}', accent: MohajonWarm.green),
                  ),
                  for (final order in orders.take(8))
                    _OrderCard(
                      order: order,
                      onReceive: order.status == 'RECEIVED' ? null : () => _receiveOrder(order),
                      onReturn: order.receivedQty.isEmpty ? null : () => _returnOrder(order),
                    ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
          if (recommendations.isEmpty) ...[
            InsightSectionTitle(
              title: l10n.t('purchaseBrief'),
              icon: Icons.check_circle_rounded,
              accent: MohajonWarm.green,
            ),
            InsightEmptyCard(
              message: l10n.t('purchaseHealthy'),
              caption: l10n.t('purchaseNone'),
              icon: Icons.verified_rounded,
              accent: MohajonWarm.green,
            ),
          ] else ...[
            InsightSectionTitle(
              title: l10n.t('purchaseRecommended'),
              icon: Icons.inventory_2_rounded,
              trailing: InsightBadge(
                label: '${recommendations.length}',
                accent: MohajonWarm.orange,
              ),
            ),
            for (final item in recommendations) ...[
              _RecommendationCard(item: item),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: InsightTokens.cardDecoration(),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: isBusy
                          ? null
                          : () => _createOrder(recommendations, budget),
                      icon: isBusy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.playlist_add_check_rounded, size: 19),
                      label: Text(
                        l10n.tP('purchaseCreateOrder', {
                          'amount': money(total.clamp(0, budget).toDouble()),
                        }),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  if (overBudget) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: MohajonWarm.red,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            l10n.tP('purchaseCreateOrder', {
                              'amount': money(budget),
                            }),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: MohajonWarm.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
      label: l10n.t('purchaseSaving'),
    );
  }

  Future<void> _createOrder(
    List<PurchaseRecommendation> recommendations,
    double budget,
  ) async {
    try {
      final order = await runBusyAction(
        () => ref.read(purchasePlannerServiceProvider).createOrder(
              recommendations: recommendations,
              budget: budget,
            ),
      );
      if (!mounted || order == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)
                .tP('purchaseSaved', {'count': '${order.items.length}'}),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }

  Future<void> _receiveOrder(PurchaseOrder order) async {
    final l10n = AppLocalizations.of(context);
    final controllers = <String, TextEditingController>{
      for (final item in order.items)
        item.productId: TextEditingController(
          text: (item.qty - (order.receivedQty[item.productId] ?? 0))
              .clamp(0, double.infinity)
              .toStringAsFixed(0),
        ),
    };
    try {
      final quantities = await showDialog<Map<String, double>>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.t('receivePurchase')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in order.items) ...[
                  Text('${item.name} • remaining ${item.qty - (order.receivedQty[item.productId] ?? 0)}'),
                  TextField(
                    controller: controllers[item.productId],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: l10n.t('receivedQuantity')),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.t('cancel'))),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                controllers.map((key, controller) => MapEntry(key, double.tryParse(controller.text) ?? 0)),
              ),
              child: Text(l10n.t('receive')),
            ),
          ],
        ),
      );
      if (quantities == null || !mounted) return;
      await ref.read(purchaseServiceProvider).receiveOrder(orderId: order.orderId, quantities: quantities);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('purchaseReceived'))));
    } finally {
      for (final controller in controllers.values) {
        controller.dispose();
      }
    }
  }

  Future<void> _returnOrder(PurchaseOrder order) async {
    final l10n = AppLocalizations.of(context);
    final controllers = <String, TextEditingController>{
      for (final item in order.items)
        item.productId: TextEditingController(text: '0'),
    };
    final reason = TextEditingController();
    try {
      final result = await showDialog<(Map<String, double>, String)?>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.t('supplierReturn')),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final item in order.items) ...[
                Text(item.name),
                TextField(
                  controller: controllers[item.productId],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: l10n.t('returnQuantity')),
                ),
              ],
              const SizedBox(height: 8),
              TextField(controller: reason, maxLines: 2, decoration: InputDecoration(labelText: l10n.t('returnReason'))),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.t('cancel'))),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, (
                controllers.map((key, value) => MapEntry(key, double.tryParse(value.text) ?? 0)),
                reason.text,
              )),
              child: Text(l10n.t('returnToSupplier')),
            ),
          ],
        ),
      );
      if (result == null || !mounted) return;
      await ref.read(purchaseServiceProvider).returnFromOrder(
            orderId: order.orderId,
            quantities: result.$1,
            reason: result.$2,
          );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('supplierReturnSaved'))));
    } finally {
      for (final controller in controllers.values) {
        controller.dispose();
      }
      reason.dispose();
    }
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onReceive, required this.onReturn});
  final PurchaseOrder order;
  final VoidCallback? onReceive;
  final VoidCallback? onReturn;

  @override
  Widget build(BuildContext context) {
    final color = order.status == 'RECEIVED' ? MohajonWarm.green : MohajonWarm.orange;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: InsightTokens.cardDecoration(radius: 16),
      child: Row(
        children: [
          Icon(Icons.local_shipping_rounded, color: color),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${order.items.length} items • ${order.status}', style: const TextStyle(fontWeight: FontWeight.w900, color: MohajonWarm.ink)),
            const SizedBox(height: 3),
            Text(money(order.totalAmount), style: const TextStyle(fontSize: 12, color: MohajonWarm.muted)),
          ])),
          if (onReceive != null) IconButton(onPressed: onReceive, tooltip: AppLocalizations.of(context).t('receivePurchase'), icon: const Icon(Icons.move_to_inbox_rounded)),
          if (onReturn != null) IconButton(onPressed: onReturn, tooltip: AppLocalizations.of(context).t('supplierReturn'), icon: const Icon(Icons.assignment_return_outlined)),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.item});

  final PurchaseRecommendation item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = item.product.stockQty <= 0
        ? MohajonWarm.red
        : item.dailyVelocity >= 1
            ? MohajonWarm.orange
            : MohajonWarm.green;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: InsightTokens.cardDecoration(radius: 16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accent, accent.withValues(alpha: 0.65)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              item.suggestedQty.toStringAsFixed(0),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.product.nameEn,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: MohajonWarm.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _MiniChip(
                      label: '${item.product.stockQty} in stock',
                      accent: item.product.stockQty <= 0
                          ? MohajonWarm.red
                          : MohajonWarm.muted,
                    ),
                    _MiniChip(
                      label: '${item.dailyVelocity.toStringAsFixed(1)}/day',
                      accent: accent,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.supplier?.name ?? l10n.t('purchaseNoSupplier'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: MohajonWarm.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                money(item.estimatedTotal),
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: MohajonWarm.ink,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: MohajonWarm.muted,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: accent,
        ),
      ),
    );
  }
}
