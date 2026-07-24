import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/product.dart';
import '../../../core/widgets/async_action_state.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';
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
  final _name = TextEditingController();
  final _barcode = TextEditingController();
  final _buyingPrice = TextEditingController();
  final _sellingPrice = TextEditingController();
  final _stockQty = TextEditingController();
  final _lowStock = TextEditingController();
  String _selectedCategory = 'Grocery';
  String _selectedUnit = 'pcs';
  String? _imagePath;
  final _picker = ImagePicker();

  static const _categories = [
    'Grocery',
    'Beverages',
    'Personal Care',
    'Rice',
    'Dairy',
    'Meat',
    'Vegetables',
    'Health',
  ];

  static const _units = ['pcs', 'kg', 'g', 'L', 'ml', 'dozen', 'box', 'pack'];

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _name.text = product?.nameEn ?? '';
    _barcode.text = product?.barcode ?? '';
    _buyingPrice.text = (product?.buyingPrice ?? 0).toString();
    _sellingPrice.text = (product?.sellingPrice ?? 0).toString();
    _stockQty.text = (product?.stockQty ?? 0).toString();
    _lowStock.text = (product?.lowStockAlert ?? 10).toString();
    _selectedCategory = product?.category.isNotEmpty == true
        ? product!.category
        : 'Grocery';
    _selectedUnit = product?.unit.isNotEmpty == true ? product!.unit : 'pcs';
    _imagePath = product?.imagePath;
  }

  @override
  void dispose() {
    _name.dispose();
    _barcode.dispose();
    _buyingPrice.dispose();
    _sellingPrice.dispose();
    _stockQty.dispose();
    _lowStock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;
    final categories = _categoryOptions();
    return withLoadingOverlay(
      Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'Edit Product' : 'Add Product'),
          actions: [
            const NotificationBell(),
            const SizedBox(width: 6),
            const ShopAvatar(),
            const SizedBox(width: 12),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              const _FieldLabel(label: 'Product Image'),
              const SizedBox(height: 8),
              _ImagePlaceholder(
                imagePath: _imagePath,
                onTap: isBusy ? null : _pickImage,
              ),
              const SizedBox(height: 14),
              const _FieldLabel(label: 'Product Name', required: true),
              const SizedBox(height: 8),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  hintText: 'e.g. Pran Tomato Sauce 200g',
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              const _FieldLabel(label: 'Barcode'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _barcode,
                decoration: InputDecoration(
                  hintText: 'Scan or type barcode',
                  suffixIcon: IconButton(
                    tooltip: 'Scan',
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    onPressed: isBusy ? null : _scanBarcode,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const _FieldLabel(label: 'Category', required: true),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in categories)
                    _ChoiceChip(
                      label: category,
                      selected: _selectedCategory == category,
                      onTap: () => setState(() => _selectedCategory = category),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel(label: 'Buying Price (৳)', required: true),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _buyingPrice,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(hintText: '0.00'),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Required'
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel(label: 'Selling Price (৳)', required: true),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _sellingPrice,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(hintText: '0.00'),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Required'
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const _FieldLabel(label: 'Unit'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final unit in _units)
                    _ChoiceChip(
                      label: unit,
                      selected: _selectedUnit == unit,
                      onTap: () =>
                          setState(() => _selectedUnit = unit),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel(label: 'Stock Qty', required: true),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _stockQty,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(hintText: '0'),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) return 'Required';
                            final parsed = int.tryParse(value.trim());
                            if (parsed == null || parsed < 0) return 'Enter a valid whole number';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel(label: 'Min Alert', required: true),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _lowStock,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(hintText: '10'),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) return 'Required';
                            final parsed = int.tryParse(value.trim());
                            if (parsed == null || parsed < 0) return 'Enter a valid whole number';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E5),
                  border: Border.all(color: const Color(0xFFFFD29C)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: Color(0xFFF97316),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'When stock falls below the minimum alert level, you will receive a low-stock notification on the Home dashboard.',
                        style: TextStyle(color: Color(0xFFB45309)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: isBusy ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(isEditing ? 'Update Product' : 'Save Product'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 46,
                child: OutlinedButton(
                  onPressed: isBusy ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              if (isEditing) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: isBusy ? null : _deleteProduct,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ],
            ],
          ),
        ),
      ),
      label: widget.product == null
          ? 'Saving product...'
          : 'Updating product...',
    );
  }

  List<String> _categoryOptions() {
    final categories = <String>[
      ..._categories,
      if (!_categories.contains(_selectedCategory) &&
          _selectedCategory.isNotEmpty)
        _selectedCategory,
    ];
    return categories;
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
    );
    if (code != null && code.isNotEmpty) {
      setState(() => _barcode.text = code);
    }
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _imagePath = picked.path);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await runBusyAction(() async {
      await ref
          .read(productServiceProvider)
          .save(
            productId: widget.product?.productId,
            nameEn: _name.text.trim(),
            nameBn: _name.text.trim(),
            barcode: _barcode.text.trim(),
            category: _selectedCategory,
            unit: _selectedUnit,
            imagePath: _imagePath,
            buyingPrice: double.tryParse(_buyingPrice.text) ?? 0,
            purchasePrice: double.tryParse(_buyingPrice.text) ?? 0,
            sellingPrice: double.tryParse(_sellingPrice.text) ?? 0,
            stockQty: int.tryParse(_stockQty.text) ?? 0,
            lowStockAlert: int.tryParse(_lowStock.text) ?? 0,
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

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE98300) : const Color(0xFFF7F5F0),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFFE98300) : const Color(0xFFE8DECF),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF475467),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, this.required = false});

  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF101828),
          fontWeight: FontWeight.w700,
        ),
        children: [
          TextSpan(text: label),
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
        ],
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.onTap, this.imagePath});

  final VoidCallback? onTap;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFFCFBF8),
          border: Border.all(color: const Color(0xFFE8DECF)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: imagePath != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      File(imagePath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE4BF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Icon(
              Icons.photo_camera_rounded,
              color: Color(0xFFE98300),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap to upload image',
            style: TextStyle(
              color: Color(0xFF98A2B3),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
