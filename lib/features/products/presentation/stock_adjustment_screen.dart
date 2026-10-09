import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/product.dart';
import '../../../core/models/stock_adjustment.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/snackbar.dart';
import '../../branches/providers/branch_providers.dart';
import '../providers/product_providers.dart';

class StockAdjustmentScreen extends ConsumerStatefulWidget {
  const StockAdjustmentScreen({super.key});

  @override
  ConsumerState<StockAdjustmentScreen> createState() =>
      _StockAdjustmentScreenState();
}

class _StockAdjustmentScreenState extends ConsumerState<StockAdjustmentScreen> {
  final _delta = TextEditingController();
  final _reason = TextEditingController();
  String? _productId;
  bool _saving = false;

  @override
  void dispose() {
    _delta.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit(List<Product> products) async {
    final l10n = AppLocalizations.of(context);
    final productId = _productId;
    final delta = int.tryParse(_delta.text.trim());
    if (productId == null ||
        delta == null ||
        delta == 0 ||
        _reason.text.trim().length < 3) {
      showAppSnackBar(context, l10n.t('adjustmentFormInvalid'), isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await ref
          .read(productServiceProvider)
          .requestStockAdjustment(
            productId: productId,
            delta: delta,
            reason: _reason.text,
          );
      if (!mounted) return;
      _delta.clear();
      _reason.clear();
      showAppSnackBar(
        context,
        result.status == StockAdjustmentStatus.pendingApproval
            ? l10n.t('adjustmentSubmitted')
            : l10n.t('adjustmentApproved'),
      );
    } catch (error) {
      if (mounted) showAppSnackBar(context, error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final products = ref.watch(productsProvider).value ?? const <Product>[];
    final shopId = ref.watch(shopIdProvider);
    final branchId = ref.watch(currentBranchIdProvider) ?? '$shopId-main';
    final adjustments = ref
        .watch(localDatabaseProvider)
        .stockAdjustments
        .watchForShop(shopId);
    final isOwner = ref.watch(currentUserProvider)?.role.name == 'owner';

    return Theme(
      data: MohajonWarm.theme(Theme.of(context)),
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.t('stockAdjustments'))),
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: MohajonWarm.pageGradient),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _AdjustmentForm(
                products: products,
                selectedProductId: _productId,
                delta: _delta,
                reason: _reason,
                saving: _saving,
                onProductChanged: (value) => setState(() => _productId = value),
                onSubmit: () => _submit(products),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.t('adjustmentHistory'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: MohajonWarm.ink,
                ),
              ),
              const SizedBox(height: 10),
              StreamBuilder<List<StockAdjustment>>(
                stream: adjustments,
                builder: (context, snapshot) {
                  final rows = (snapshot.data ?? const <StockAdjustment>[])
                      .where(
                        (item) => (item.branchId ?? '$shopId-main') == branchId,
                      )
                      .toList();
                  if (rows.isEmpty) {
                    return Text(
                      l10n.t('noAdjustments'),
                      style: const TextStyle(color: MohajonWarm.muted),
                    );
                  }
                  return Column(
                    children: [
                      for (final row in rows.take(30))
                        _AdjustmentRow(
                          adjustment: row,
                          productName:
                              products
                                  .where((p) => p.productId == row.productId)
                                  .firstOrNull
                                  ?.nameEn ??
                              row.productId,
                          isOwner: isOwner,
                          onApprove: () => ref
                              .read(productServiceProvider)
                              .approveStockAdjustment(row.adjustmentId),
                          onReject: () => ref
                              .read(productServiceProvider)
                              .rejectStockAdjustment(row.adjustmentId),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdjustmentForm extends StatelessWidget {
  const _AdjustmentForm({
    required this.products,
    required this.selectedProductId,
    required this.delta,
    required this.reason,
    required this.saving,
    required this.onProductChanged,
    required this.onSubmit,
  });
  final List<Product> products;
  final String? selectedProductId;
  final TextEditingController delta;
  final TextEditingController reason;
  final bool saving;
  final ValueChanged<String?> onProductChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MohajonWarm.goldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.t('requestStockAdjustment'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: MohajonWarm.ink,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selectedProductId,
            decoration: InputDecoration(labelText: l10n.t('product')),
            items: products
                .map(
                  (p) => DropdownMenuItem(
                    value: p.productId,
                    child: Text(p.nameEn, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: onProductChanged,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: delta,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.t('adjustmentQuantity'),
              hintText: '+10 or -3',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: reason,
            maxLines: 2,
            decoration: InputDecoration(labelText: l10n.t('adjustmentReason')),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: saving ? null : onSubmit,
              icon: const Icon(Icons.send_rounded),
              label: Text(l10n.t('submitAdjustment')),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdjustmentRow extends StatelessWidget {
  const _AdjustmentRow({
    required this.adjustment,
    required this.productName,
    required this.isOwner,
    required this.onApprove,
    required this.onReject,
  });
  final StockAdjustment adjustment;
  final String productName;
  final bool isOwner;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final pending = adjustment.status == StockAdjustmentStatus.pendingApproval;
    final color = adjustment.status == StockAdjustmentStatus.approved
        ? MohajonWarm.green
        : adjustment.status == StockAdjustmentStatus.rejected
        ? MohajonWarm.red
        : MohajonWarm.orange;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: MohajonWarm.card.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MohajonWarm.goldBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.tune_rounded, color: color, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$productName  ${adjustment.delta > 0 ? '+' : ''}${adjustment.delta}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  adjustment.reason,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MohajonWarm.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (pending && isOwner)
            Wrap(
              spacing: 2,
              children: [
                IconButton(
                  onPressed: onApprove,
                  color: MohajonWarm.green,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                ),
                IconButton(
                  onPressed: onReject,
                  color: MohajonWarm.red,
                  icon: const Icon(Icons.cancel_outlined),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Icon(Icons.circle, size: 9, color: color),
            ),
        ],
      ),
    );
  }
}
