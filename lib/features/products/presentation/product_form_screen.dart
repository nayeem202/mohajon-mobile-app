import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/product.dart';
import '../../../core/widgets/async_action_state.dart';
import '../providers/product_providers.dart';
import 'barcode_scan_screen.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.product});

  final Product? product;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen>
    with AsyncActionState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameEn;
  late final TextEditingController _nameBn;
  late final TextEditingController _barcode;
  late final TextEditingController _category;
  late final TextEditingController _purchasePrice;
  late final TextEditingController _sellingPrice;
  late final TextEditingController _stockQty;
  late final TextEditingController _lowStock;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameEn = TextEditingController(text: product?.nameEn ?? '');
    _nameBn = TextEditingController(text: product?.nameBn ?? '');
    _barcode = TextEditingController(text: product?.barcode ?? '');
    _category = TextEditingController(text: product?.category ?? '');
    _purchasePrice = TextEditingController(text: product?.purchasePrice.toString() ?? '');
    _sellingPrice = TextEditingController(text: product?.sellingPrice.toString() ?? '');
    _stockQty = TextEditingController(text: product?.stockQty.toString() ?? '');
    _lowStock = TextEditingController(text: product?.lowStockAlert.toString() ?? '5');
  }

  @override
  void dispose() {
    _nameEn.dispose();
    _nameBn.dispose();
    _barcode.dispose();
    _category.dispose();
    _purchasePrice.dispose();
    _sellingPrice.dispose();
    _stockQty.dispose();
    _lowStock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return withLoadingOverlay(
      Scaffold(
        appBar: AppBar(
          title: Text(widget.product == null ? 'Add product' : 'Edit product'),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _field(_nameEn, 'Name (EN)'),
              _field(_nameBn, 'Name (BN)'),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: _barcode,
                  decoration: InputDecoration(
                    labelText: 'Barcode',
                    suffixIcon: IconButton(
                      tooltip: 'Scan',
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: isBusy
                          ? null
                          : () async {
                              final code = await Navigator.of(context)
                                  .push<String>(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const BarcodeScanScreen(),
                                    ),
                                  );
                              if (code != null) _barcode.text = code;
                            },
                    ),
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                ),
              ),
              _field(_category, 'Category'),
              _field(_purchasePrice, 'Purchase price', number: true),
              _field(_sellingPrice, 'Selling price', number: true),
              _field(_stockQty, 'Stock quantity', number: true),
              _field(_lowStock, 'Low stock alert', number: true),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: isBusy ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save'),
              ),
              if (widget.product != null)
                TextButton.icon(
                  onPressed: isBusy ? null : _deleteProduct,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
            ],
          ),
        ),
      ),
      label:
          widget.product == null ? 'Saving product...' : 'Updating product...',
    );
  }

  Widget _field(TextEditingController controller, String label, {bool number = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        decoration: InputDecoration(labelText: label),
        validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await runBusyAction(() async {
      await ref.read(productServiceProvider).save(
            productId: widget.product?.productId,
            nameEn: _nameEn.text.trim(),
            nameBn: _nameBn.text.trim(),
            barcode: _barcode.text.trim(),
            category: _category.text.trim(),
            purchasePrice: double.tryParse(_purchasePrice.text) ?? 0,
            sellingPrice: double.tryParse(_sellingPrice.text) ?? 0,
            stockQty: double.tryParse(_stockQty.text) ?? 0,
            lowStockAlert: double.tryParse(_lowStock.text) ?? 0,
          );
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _deleteProduct() async {
    await runBusyAction(() async {
      await ref.read(productServiceProvider).delete(widget.product!.productId);
      if (mounted) Navigator.of(context).pop();
    });
  }
}
