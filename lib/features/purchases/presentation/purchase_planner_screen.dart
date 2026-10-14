import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/product.dart';
import '../../../core/models/purchase.dart';
import '../../../core/models/sale.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/app_error.dart';
import '../../../core/widgets/async_action_state.dart';
import '../../../core/widgets/insight_widgets.dart';
import '../../customers/providers/customer_providers.dart';
import '../../expenses/providers/expense_providers.dart';
import '../../products/providers/product_providers.dart';
import '../../branches/providers/branch_providers.dart';
import '../providers/purchase_providers.dart';
import '../models/purchase_order.dart';
import 'purchase_receipt_dialog.dart';
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
    final calculatedBudget = planner.cashBudget(
      sales: sales,
      expenses: expenses,
    );
    final budget = double.tryParse(_budgetController.text) ?? calculatedBudget;
    final total = recommendations.fold<double>(
      0,
      (sum, item) => sum + item.estimatedTotal,
    );
    final stockAttention = recommendations
        .where(
          (item) =>
              item.product.stockQty <= 0 ||
              item.product.isLowStock ||
              (item.dailyVelocity > 0 && item.coverageDays <= 7),
        )
        .toList();
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
          icon: const Icon(
            Icons.sync_rounded,
            color: MohajonWarm.ink,
            size: 20,
          ),
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
            decoration: InsightTokens.cardDecoration(
              accent: MohajonWarm.primary,
            ),
            child: TextField(
              controller: _budgetController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
            stream: db.purchaseOrders
                .watchForShop(ref.read(shopIdProvider))
                .map((items) {
                  final shopId = ref.read(shopIdProvider);
                  final branchId =
                      ref.read(currentBranchIdProvider) ?? '$shopId-main';
                  return items
                      .where(
                        (item) => (item.branchId ?? '$shopId-main') == branchId,
                      )
                      .toList();
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
                    trailing: InsightBadge(
                      label: '${orders.length}',
                      accent: MohajonWarm.green,
                    ),
                  ),
                  for (final order in orders.take(8))
                    _OrderCard(
                      order: order,
                      onReceive: order.status == 'RECEIVED'
                          ? null
                          : () => _receiveOrder(order),
                      onReturn: order.receivedQty.isEmpty
                          ? null
                          : () => _returnOrder(order),
                    ),
                  finalSupplierInsights(
                    orders,
                    db.suppliers.valuesForShop(ref.read(shopIdProvider)),
                    l10n,
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
          if (stockAttention.isNotEmpty) ...[
            InsightSectionTitle(
              title: l10n.t('purchaseStockAttention'),
              icon: Icons.notification_important_rounded,
              accent: MohajonWarm.red,
              trailing: InsightBadge(
                label: '${stockAttention.length}',
                accent: MohajonWarm.red,
              ),
            ),
            _StockAttentionCard(items: stockAttention),
            const SizedBox(height: 8),
          ],
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
              decoration: InsightTokens.cardDecoration(
                accent: MohajonWarm.green,
              ),
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
                          : const Icon(
                              Icons.playlist_add_check_rounded,
                              size: 19,
                            ),
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
        () => ref
            .read(purchasePlannerServiceProvider)
            .createOrder(recommendations: recommendations, budget: budget),
      );
      if (!mounted || order == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).tP('purchaseSaved', {'count': '${order.items.length}'}),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyErrorMessage(error, l10n: AppLocalizations.of(context)),
          ),
        ),
      );
    }
  }

  Future<void> _receiveOrder(PurchaseOrder order) async {
    final l10n = AppLocalizations.of(context);
    final receipt = await showPurchaseReceiptDialog(context, order);
    if (receipt == null || !mounted) return;
    try {
      await ref
          .read(purchaseServiceProvider)
          .receiveOrder(
            orderId: order.orderId,
            deliveredQuantities: receipt.delivered,
            damagedQuantities: receipt.damaged,
            actualUnitCosts: receipt.unitCosts,
            itemIssueNotes: receipt.issueNotes,
            invoiceAmount: receipt.invoiceAmount,
            invoiceNumber: receipt.invoiceNumber,
            freightAmount: receipt.freightAmount,
            discountAmount: receipt.discountAmount,
            attachmentPath: receipt.attachmentPath,
            notes: receipt.notes,
          );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.t('supplierReceiptSaved'))));
      }
    } catch (error) {
      if (!mounted) return;
      final message = friendlyErrorMessage(error, l10n: l10n);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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
        builder: (dialogContext) => Theme(
          data: MohajonWarm.theme(Theme.of(context)),
          child: AlertDialog(
            title: Text(l10n.t('supplierReturn')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final item in order.items) ...[
                    Text(item.name),
                    TextField(
                      controller: controllers[item.productId],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.t('returnQuantity'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextField(
                    controller: reason,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: l10n.t('returnReason'),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l10n.t('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, (
                  controllers.map(
                    (key, value) =>
                        MapEntry(key, double.tryParse(value.text) ?? 0),
                  ),
                  reason.text,
                )),
                child: Text(l10n.t('returnToSupplier')),
              ),
            ],
          ),
        ),
      );
      if (result == null || !mounted) return;
      await ref
          .read(purchaseServiceProvider)
          .returnFromOrder(
            orderId: order.orderId,
            quantities: result.$1,
            reason: result.$2,
          );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.t('supplierReturnSaved'))));
      }
    } finally {
      for (final controller in controllers.values) {
        controller.dispose();
      }
      reason.dispose();
    }
  }
}

Widget finalSupplierInsights(
  List<PurchaseOrder> orders,
  List<dynamic> suppliers,
  AppLocalizations l10n,
) {
  final completed = orders
      .where((order) => order.status == 'RECEIVED')
      .toList();
  if (completed.isEmpty) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        l10n.t('noSupplierReceiptHistory'),
        style: const TextStyle(color: MohajonWarm.muted, fontSize: 12),
      ),
    );
  }
  final metrics = <String, _SupplierMetric>{};
  for (final order in completed) {
    final metric = metrics.putIfAbsent(order.supplierId, _SupplierMetric.new);
    metric.orderCount++;
    for (final item in order.items) {
      metric.ordered += item.qty;
      metric.accepted += order.receivedQty[item.productId] ?? 0;
      metric.damaged += order.receipts
          .expand((receipt) => receipt.items)
          .where((receiptItem) => receiptItem.productId == item.productId)
          .fold<double>(0, (sum, receiptItem) => sum + receiptItem.damagedQty);
      metric.delivered +=
          order.deliveredQty[item.productId] ??
          order.receivedQty[item.productId] ??
          0;
    }
    metric.invoiceVariance += order.receipts.fold<double>(
      0,
      (sum, receipt) => sum + receipt.invoiceVariance,
    );
  }
  if (metrics.isEmpty) return const SizedBox.shrink();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      InsightSectionTitle(
        title: l10n.t('supplierPerformance'),
        icon: Icons.local_shipping_rounded,
      ),
      for (final entry in metrics.entries)
        _SupplierPerformanceCard(
          name:
              suppliers
                  .where((item) => item.supplierId == entry.key)
                  .map((item) => item.name as String)
                  .firstOrNull ??
              l10n.t('supplierLabel'),
          metric: entry.value,
          l10n: l10n,
        ),
    ],
  );
}

class _SupplierMetric {
  int orderCount = 0;
  double ordered = 0;
  double accepted = 0;
  double delivered = 0;
  double damaged = 0;
  double invoiceVariance = 0;
}

class _SupplierPerformanceCard extends StatelessWidget {
  const _SupplierPerformanceCard({
    required this.name,
    required this.metric,
    required this.l10n,
  });
  final String name;
  final _SupplierMetric metric;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final fillRate = metric.ordered <= 0
        ? 0.0
        : metric.accepted / metric.ordered;
    final issueRate = metric.ordered <= 0
        ? 0.0
        : ((metric.ordered - metric.delivered + metric.damaged) /
                  metric.ordered)
              .clamp(0, 1);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: InsightTokens.cardDecoration(accent: MohajonWarm.orange),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: MohajonWarm.tintOrange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: MohajonWarm.orange,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.tP('supplierOrderCount', {
                        'count': '${metric.orderCount}',
                      }),
                      style: const TextStyle(
                        color: MohajonWarm.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 390;
              final gap = 8.0;
              final tileWidth = compact
                  ? (constraints.maxWidth - gap) / 2
                  : (constraints.maxWidth - gap * 2) / 3;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  _SupplierMetricValue(
                    width: tileWidth,
                    label: l10n.t('supplierFillRate'),
                    value: '${(fillRate * 100).round()}%',
                    accent: MohajonWarm.green,
                  ),
                  _SupplierMetricValue(
                    width: tileWidth,
                    label: l10n.t('supplierIssueRate'),
                    value: '${(issueRate * 100).round()}%',
                    accent: issueRate > 0
                        ? MohajonWarm.orange
                        : MohajonWarm.green,
                  ),
                  _SupplierMetricValue(
                    width: tileWidth,
                    label: l10n.t('supplierInvoiceVariance'),
                    value: money(metric.invoiceVariance),
                    accent: metric.invoiceVariance.abs() > .01
                        ? MohajonWarm.orange
                        : MohajonWarm.ink,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SupplierMetricValue extends StatelessWidget {
  const _SupplierMetricValue({
    required this.width,
    required this.label,
    required this.value,
    required this.accent,
  });
  final double width;
  final String label;
  final String value;
  final Color accent;
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .72),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: MohajonWarm.goldBorder.withValues(alpha: .7)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: MohajonWarm.muted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: accent,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.onReceive,
    required this.onReturn,
  });
  final PurchaseOrder order;
  final VoidCallback? onReceive;
  final VoidCallback? onReturn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = order.status == 'RECEIVED'
        ? MohajonWarm.green
        : MohajonWarm.orange;
    final statusLabel = order.status == 'RECEIVED'
        ? l10n.t('purchaseStatusReceived')
        : l10n.t('purchaseStatusPending');
    final latestReceipt = order.receipts.isEmpty ? null : order.receipts.last;
    final damaged =
        latestReceipt?.items.fold<double>(
          0,
          (sum, item) => sum + item.damagedQty,
        ) ??
        0;
    final short =
        latestReceipt?.items.fold<double>(
          0,
          (sum, item) => sum + item.shortQty,
        ) ??
        0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: InsightTokens.cardDecoration(radius: 18, accent: color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.local_shipping_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.tP('purchaseItemsCount', {
                    'count': '${order.items.length}',
                  }),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: MohajonWarm.ink,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  money(order.totalAmount),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: MohajonWarm.ink,
                  ),
                ),
                if (latestReceipt != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${l10n.t('supplierInvoiceNumber')}: ${latestReceipt.invoiceNumber.isEmpty ? '—' : latestReceipt.invoiceNumber}  •  ${money(latestReceipt.invoiceAmount)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: MohajonWarm.muted,
                    ),
                  ),
                  Text(
                    '${l10n.t('damagedQty')}: ${damaged.toStringAsFixed(0)}  •  ${l10n.t('shortQty')}: ${short.toStringAsFixed(0)}  •  ${l10n.t('supplierInvoiceVariance')}: ${money(latestReceipt.invoiceVariance)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: latestReceipt.invoiceVariance.abs() > 0.01
                          ? MohajonWarm.orange
                          : MohajonWarm.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (latestReceipt.attachmentPath.isNotEmpty)
                    _ReceiptAttachment(path: latestReceipt.attachmentPath),
                ],
              ],
            ),
          ),
          if (onReceive != null || onReturn != null) ...[
            const SizedBox(height: 8),
            const Divider(height: 1, color: MohajonWarm.goldBorder),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 6,
                children: [
                  if (onReceive != null)
                    TextButton.icon(
                      onPressed: onReceive,
                      icon: const Icon(Icons.move_to_inbox_rounded, size: 17),
                      label: Text(l10n.t('receivePurchase')),
                    ),
                  if (onReturn != null)
                    TextButton.icon(
                      onPressed: onReturn,
                      icon: const Icon(
                        Icons.assignment_return_outlined,
                        size: 17,
                      ),
                      label: Text(l10n.t('supplierReturn')),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReceiptAttachment extends StatelessWidget {
  const _ReceiptAttachment({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => Dialog(
            child: InteractiveViewer(
              child: path.startsWith('http')
                  ? Image.network(path, fit: BoxFit.contain)
                  : Image.file(File(path), fit: BoxFit.contain),
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: path.startsWith('http')
              ? Image.network(
                  path,
                  width: 52,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.broken_image_outlined),
                )
              : Image.file(
                  File(path),
                  width: 52,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.broken_image_outlined),
                ),
        ),
      ),
    ),
  );
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.item});

  final PurchaseRecommendation item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = l10n.locale.languageCode;
    final accent = item.product.stockQty <= 0
        ? MohajonWarm.red
        : item.dailyVelocity >= 1
        ? MohajonWarm.orange
        : MohajonWarm.green;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: InsightTokens.cardDecoration(radius: 18, accent: accent),
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
                  item.product.displayName(language),
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
                      label: l10n.tP('qtyInStock', {
                        'qty': '${item.product.stockQty}',
                      }),
                      accent: item.product.stockQty <= 0
                          ? MohajonWarm.red
                          : MohajonWarm.muted,
                    ),
                    _MiniChip(
                      label: l10n.tP('purchaseDailyVelocity', {
                        'qty': item.dailyVelocity.toStringAsFixed(1),
                      }),
                      accent: accent,
                    ),
                    _MiniChip(
                      label: item.product.stockQty <= 0
                          ? l10n.t('outOfStock')
                          : item.dailyVelocity <= 0 ||
                                item.coverageDays.isInfinite
                          ? l10n.t('purchaseCoverUnknown')
                          : l10n.tP('purchaseStockCoverDays', {
                              'days': '${item.coverageDays.ceil()}',
                            }),
                      accent: item.product.stockQty <= 0
                          ? MohajonWarm.red
                          : item.coverageDays <= 7
                          ? MohajonWarm.red
                          : MohajonWarm.green,
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

class _StockAttentionCard extends StatelessWidget {
  const _StockAttentionCard({required this.items});

  final List<PurchaseRecommendation> items;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final outOfStock = items.where((item) => item.product.stockQty <= 0).length;
    final runningOut = items
        .where(
          (item) =>
              item.product.stockQty > 0 &&
              item.dailyVelocity > 0 &&
              item.coverageDays <= 7,
        )
        .length;
    final message = outOfStock > 0
        ? l10n.tP('purchaseOutOfStockCount', {'count': '$outOfStock'})
        : runningOut > 0
        ? l10n.tP('purchaseRunningOutCount', {'count': '$runningOut'})
        : l10n.tP('purchaseBelowMinimumCount', {'count': '${items.length}'});
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MohajonWarm.red.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0.94),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MohajonWarm.red.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: MohajonWarm.red,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: MohajonWarm.ink,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
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
