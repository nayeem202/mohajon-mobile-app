import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../core/utils/snackbar.dart';
import '../../../core/utils/app_error.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/product.dart';
import '../../../core/app/app_providers.dart';
import '../../../core/constants/shop_category_templates.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/widgets/action_button.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/async_action_state.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';
import '../providers/product_providers.dart';
import '../services/barcode_label_service.dart';
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
  DateTime? _expiryDate;
  final _batchNumber = TextEditingController();
  final _sku = TextEditingController();
  final _variantName = TextEditingController();
  String _selectedCategory = 'Grocery';
  String _selectedUnit = 'pcs';
  String? _imagePath;
  final _picker = ImagePicker();

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
    _expiryDate = product?.expiryDate;
    _batchNumber.text = product?.batchNumber ?? '';
    _sku.text = product?.sku ?? '';
    _variantName.text = product?.variantName ?? '';
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
    _batchNumber.dispose();
    _sku.dispose();
    _variantName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;
    final categories = _categoryOptions();
    final l10n = AppLocalizations.of(context);
    return withLoadingOverlay(
      Theme(
        data: MohajonWarm.theme(Theme.of(context)),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: DecoratedBox(
            decoration: const BoxDecoration(gradient: MohajonWarm.pageGradient),
            child: Stack(
              children: [
                ..._buildDecorativeCircles(),
                SafeArea(
                  child: Column(
                    children: [
                      Expanded(
                        child: Form(
                          key: _formKey,
                          child: ListView(
                            padding:
                                const EdgeInsets.fromLTRB(18, 12, 18, 16),
                            children: [
                              _FormHeader(
                                title: isEditing
                                    ? l10n.t('updateProduct')
                                    : l10n.t('addProduct'),
                                subtitle: l10n.t('productDetailsPricing'),
                                onBack: () =>
                                    Navigator.of(context).maybePop(),
                              ),
                              const SizedBox(height: 18),
                              _ImagePickerCard(
                                imagePath: _imagePath,
                                onTap: isBusy ? null : _pickImage,
                              ),
                              const SizedBox(height: 14),
                              _SectionCard(
                                icon: Icons.shopping_bag_outlined,
                                iconColor: MohajonWarm.goldText,
                                iconBackground: MohajonWarm.tintYellow,
                                title: l10n.t('basicInformation'),
                                children: [
                                  _FieldLabel(
                                    label: l10n.t('productName'),
                                    required: true,
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _name,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    decoration: InputDecoration(
                                      prefixIcon: const Icon(
                                        Icons.inventory_2_outlined,
                                        size: 20,
                                        color: MohajonWarm.muted,
                                      ),
                                      hintText: l10n.t('productNameHint'),
                                    ),
                                    validator: (value) =>
                                        value == null ||
                                            value.trim().isEmpty
                                        ? l10n.t('required')
                                        : null,
                                  ),
                                  const SizedBox(height: 14),
                                  _FieldLabel(label: l10n.t('barcode')),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _barcode,
                                    decoration: InputDecoration(
                                      hintText: l10n.t('scanOrTypeBarcode'),
                                      prefixIcon: const Icon(
                                        Icons.qr_code_rounded,
                                        size: 20,
                                        color: MohajonWarm.muted,
                                      ),
                                      suffixIcon: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: l10n.t('printBarcodeLabel'),
                                            highlightColor: MohajonWarm
                                                .primary
                                                .withValues(alpha: 0.25),
                                            icon: Icon(
                                              Icons.print_outlined,
                                              color: _barcode.text.trim().isEmpty
                                                  ? MohajonWarm.muted
                                                  : MohajonWarm.goldText,
                                            ),
                                            onPressed: isBusy ||
                                                    _barcode.text.trim().isEmpty
                                                ? null
                                                : _printBarcodeLabel,
                                          ),
                                          IconButton(
                                            tooltip: l10n.t('scanBarcode'),
                                            highlightColor: MohajonWarm
                                                .primary
                                                .withValues(alpha: 0.25),
                                            icon: const Icon(
                                              Icons.qr_code_scanner_rounded,
                                              color: MohajonWarm.goldText,
                                            ),
                                            onPressed: isBusy
                                                ? null
                                                : _scanBarcode,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _SectionCard(
                                icon: Icons.category_outlined,
                                iconColor: MohajonWarm.green,
                                iconBackground: MohajonWarm.tintGreen,
                                title: l10n.t('categorization'),
                                children: [
                                  _FieldLabel(
                                    label: l10n.t('category'),
                                    required: true,
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final category in categories)
                                        _PillChip(
                                          label: _categoryLabel(category, l10n),
                                          selected:
                                              _selectedCategory == category,
                                          onTap: () => setState(() =>
                                              _selectedCategory = category),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _FieldLabel(label: l10n.t('unit')),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final unit in _units)
                                        _PillChip(
                                          label: unit,
                                          selected: _selectedUnit == unit,
                                          onTap: () => setState(
                                              () => _selectedUnit = unit),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _SectionCard(
                                icon: Icons.payments_outlined,
                                iconColor: MohajonWarm.orange,
                                iconBackground: MohajonWarm.tintOrange,
                                title: 'Pricing',
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _FieldLabel(
                                              label: l10n.t('buyingPrice'),
                                              required: true,
                                            ),
                                            const SizedBox(height: 8),
                                            TextFormField(
                                              controller: _buyingPrice,
                                              keyboardType: const TextInputType
                                                  .numberWithOptions(
                                                decimal: true,
                                              ),
                                              decoration:
                                                  const InputDecoration(
                                                prefixIcon: Padding(
                                                  padding: EdgeInsets.only(
                                                    left: 14,
                                                    right: 8,
                                                  ),
                                                  child: Text(
                                                    '৳',
                                                    style: TextStyle(
                                                      color:
                                                          MohajonWarm.muted,
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                                prefixIconConstraints:
                                                    BoxConstraints(
                                                  minWidth: 0,
                                                  minHeight: 0,
                                                ),
                                                hintText: '0.00',
                                              ),
                                              validator: (value) =>
                                                  value == null ||
                                                      value.trim().isEmpty
                                                  ? l10n.t('required')
                                                  : null,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _FieldLabel(
                                              label: l10n.t('sellingPrice'),
                                              required: true,
                                            ),
                                            const SizedBox(height: 8),
                                            TextFormField(
                                              controller: _sellingPrice,
                                              keyboardType: const TextInputType
                                                  .numberWithOptions(
                                                decimal: true,
                                              ),
                                              decoration:
                                                  const InputDecoration(
                                                prefixIcon: Padding(
                                                  padding: EdgeInsets.only(
                                                    left: 14,
                                                    right: 8,
                                                  ),
                                                  child: Text(
                                                    '৳',
                                                    style: TextStyle(
                                                      color:
                                                          MohajonWarm.muted,
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                                prefixIconConstraints:
                                                    BoxConstraints(
                                                  minWidth: 0,
                                                  minHeight: 0,
                                                ),
                                                hintText: '0.00',
                                              ),
                                              validator: (value) =>
                                                  value == null ||
                                                      value.trim().isEmpty
                                                  ? l10n.t('required')
                                                  : null,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _SectionCard(
                                icon: Icons.inventory_outlined,
                                iconColor: MohajonWarm.red,
                                iconBackground: MohajonWarm.tintRed,
                                title: l10n.t('stockLevels'),
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _FieldLabel(
                                              label: l10n.t('stockQty'),
                                              required: true,
                                            ),
                                            const SizedBox(height: 8),
                                            TextFormField(
                                              controller: _stockQty,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: const InputDecoration(
                                                hintText: '0',
                                              ),
                                              validator: (value) {
                                                if (value == null ||
                                                    value.trim().isEmpty) {
                                                  return l10n.t('required');
                                                }
                                                final parsed =
                                                    int.tryParse(value.trim());
                                                if (parsed == null ||
                                                    parsed < 0) {
                                                  return l10n.t('validWholeNumber');
                                                }
                                                return null;
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _FieldLabel(
                                              label: l10n.t('minAlert'),
                                              required: true,
                                            ),
                                            const SizedBox(height: 8),
                                            TextFormField(
                                              controller: _lowStock,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: const InputDecoration(
                                                hintText: '10',
                                              ),
                                              validator: (value) {
                                                if (value == null ||
                                                    value.trim().isEmpty) {
                                                  return l10n.t('required');
                                                }
                                                final parsed =
                                                    int.tryParse(value.trim());
                                                if (parsed == null ||
                                                    parsed < 0) {
                                                  return l10n.t('validWholeNumber');
                                                }
                                                return null;
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
const SizedBox(height: 12),
                              _ExpiryField(
                                value: _expiryDate,
                                onChanged: (date) =>
                                    setState(() => _expiryDate = date),
                              ),
                              const SizedBox(height: 12),
                              _FieldLabel(label: l10n.t('batchNumber')),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _batchNumber,
                                textCapitalization: TextCapitalization.characters,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.qr_code_2_rounded, size: 20),
                                  hintText: l10n.t('batchNumberHint'),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _sku,
                                      textCapitalization: TextCapitalization.characters,
                                      decoration: InputDecoration(
                                        prefixIcon: const Icon(Icons.inventory_2_outlined, size: 20),
                                        labelText: l10n.t('sku'),
                                        hintText: l10n.t('skuHint'),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _variantName,
                                      decoration: InputDecoration(
                                        prefixIcon: const Icon(Icons.tune_rounded, size: 20),
                                        labelText: l10n.t('variant'),
                                        hintText: l10n.t('variantHint'),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: MohajonWarm.tintOrange,
                                      border: Border.all(
                                        color: MohajonWarm.orange
                                            .withValues(alpha: 0.25),
                                      ),
                                      borderRadius:
                                          BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.notifications_active_outlined,
                                          size: 16,
                                          color: MohajonWarm.orange,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            l10n.t('lowStockHelp'),
                                            style: const TextStyle(
                                              color: Color(0xFF9A3412),
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              height: 1.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (isEditing) ...[
                                const SizedBox(height: 8),
                                Center(
                                  child: TextButton.icon(
                                    onPressed: isBusy
                                        ? null
                                        : _deleteProduct,
                                    style: TextButton.styleFrom(
                                      foregroundColor: MohajonWarm.red,
                                      textStyle: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                    icon: const Icon(Icons.delete_outline,
                                        size: 18),
                                    label: Text(l10n.t('delete')),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      _SaveBar(
                        child: Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: OutlinedButton(
                                onPressed: isBusy
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 48),
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(
                                    color: MohajonWarm.goldBorder,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  foregroundColor: MohajonWarm.ink,
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                child: Text(l10n.t('cancel')),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: ActionButton(
                                onPressed: _save,
                                isBusy: isBusy,
                                icon: Icons.save_outlined,
                                label: isEditing
                                    ? l10n.t('updateProduct')
                                    : l10n.t('saveProduct'),
                                busyLabel: isEditing
                                    ? l10n.t('updating')
                                    : l10n.t('saving'),
                              ),
                            ),
                          ],
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
      label: widget.product == null
          ? l10n.t('savingProduct')
          : l10n.t('updatingProduct'),
    );
  }

  List<Widget> _buildDecorativeCircles() {
    return [
      Positioned(
        top: -70,
        right: -50,
        child: _circle(190, Colors.white.withValues(alpha: 0.16)),
      ),
      Positioned(
        top: 34,
        right: 96,
        child: _circle(64, Colors.white.withValues(alpha: 0.14)),
      ),
      Positioned(
        top: 110,
        left: -60,
        child: _circle(150, Colors.white.withValues(alpha: 0.10)),
      ),
    ];
  }

  Widget _circle(double size, Color color) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }

  List<String> _categoryOptions() {
    final type = ref.read(localDatabaseProvider).settings.get(
          'profile_businessType',
        ) as String?;
    final template = ShopCategoryTemplates.forId(type);
    final categories = <String>[
      ...template.categories,
      if (!template.categories.contains(_selectedCategory) &&
          _selectedCategory.isNotEmpty)
        _selectedCategory,
    ];
    return categories;
  }

  String _categoryLabel(String category, AppLocalizations l10n) {
    switch (category) {
      case 'Grocery':
        return l10n.t('catGrocery');
      case 'Beverages':
        return l10n.t('catBeverages');
      case 'Personal Care':
        return l10n.t('catPersonalCare');
      case 'Rice':
        return l10n.t('catRice');
      case 'Dairy':
        return l10n.t('catDairy');
      case 'Meat':
        return l10n.t('catMeat');
      case 'Vegetables':
        return l10n.t('catVegetables');
      case 'Health':
        return l10n.t('catHealth');
      default:
        return category;
    }
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
    );
    if (code != null && code.isNotEmpty) {
      setState(() => _barcode.text = code);
    }
  }

  Future<void> _printBarcodeLabel() async {
    final code = _barcode.text.trim();
    if (code.isEmpty) return;
    final name = _name.text.trim().isEmpty ? 'Product' : _name.text.trim();
    final price = double.tryParse(_sellingPrice.text.trim()) ?? 0;
    try {
      await Printing.layoutPdf(
        name: 'barcode-$code',
        onLayout: (format) => BarcodeLabelService().buildLabels(
          [
            BarcodeLabel(code: code, name: name, price: price),
          ],
          format: format,
        ),
      );
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          AppLocalizations.of(context).tP('failedPrintBarcode', {'error': '$e'}),
          isError: true,
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final l10n = AppLocalizations.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: MohajonWarm.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: MohajonWarm.goldBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                l10n.t('productImage'),
                style: const TextStyle(
                  color: MohajonWarm.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_outlined,
                  color: MohajonWarm.goldText,
                ),
                title: Text(
                  l10n.t('takePhoto'),
                  style: const TextStyle(
                    color: MohajonWarm.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: MohajonWarm.goldText,
                ),
                title: Text(
                  l10n.t('chooseFromGallery'),
                  style: const TextStyle(
                    color: MohajonWarm.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
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
    try {
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
              expiryDate: _expiryDate,
              batchNumber: _batchNumber.text.trim(),
              sku: _sku.text.trim(),
              variantName: _variantName.text.trim(),
            );
        if (mounted) Navigator.of(context).pop();
      });
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, friendlyErrorMessage(error), isError: true);
      }
    }
  }

  Future<void> _deleteProduct() async {
    final l10n = AppLocalizations.of(context);
    final product = widget.product;
    if (product == null) return;
    final name = product.displayName(Localizations.localeOf(context).languageCode);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return PopScope(
          canPop: true,
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.all(24),
                width: 320,
                decoration: BoxDecoration(
                  color: MohajonWarm.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: MohajonWarm.goldBorder),
                  boxShadow: [
                    BoxShadow(
                      color: MohajonWarm.ink.withValues(alpha: 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: MohajonWarm.tintRed,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: MohajonWarm.red,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.t('deleteProductQuestion'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: MohajonWarm.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.tP('deleteProductConfirm', {'desc': name}),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: MohajonWarm.muted,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: OutlinedButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(false),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: const Color(0xFFF0ECE6),
                                foregroundColor: const Color(0xFF525252),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide.none,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: Text(l10n.t('cancel')),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: FilledButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(true),
                              style: FilledButton.styleFrom(
                                backgroundColor: MohajonWarm.red,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: Text(l10n.t('delete')),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    if (confirmed != true) return;
    try {
      await runBusyAction(() async {
        await ref
            .read(productServiceProvider)
            .delete(widget.product!.productId);
        if (mounted) Navigator.of(context).pop();
      });
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, friendlyErrorMessage(error), isError: true);
      }
    }
  }
}

/// Pinned bottom bar so save/cancel actions are always reachable.
class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MohajonWarm.card,
        border: const Border(
          top: BorderSide(color: MohajonWarm.goldBorder),
        ),
        boxShadow: [
          BoxShadow(
            color: MohajonWarm.ink.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 10),
        child: child,
      ),
    );
  }
}

/// Custom warm header matching the Stock screen top bar.
class _FormHeader extends StatelessWidget {
  const _FormHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            borderRadius: BorderRadius.circular(11),
            onTap: onBack,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: MohajonWarm.goldBorder),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: MohajonWarm.ink,
                size: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [MohajonWarm.primary, MohajonWarm.primaryPale],
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: MohajonWarm.primary.withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.inventory_2_rounded,
            color: MohajonWarm.ink,
            size: 17,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: MohajonWarm.ink,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: MohajonWarm.muted,
                ),
              ),
            ],
          ),
        ),
        const NotificationBell(),
        const SizedBox(width: 14),
        const ShopAvatar(
          radius: 17,
          backgroundColor: Color(0xFFFFFDF7),
          textColor: MohajonWarm.ink,
        ),
      ],
    );
  }
}

/// White card panel with gold border matching the Stock search panel.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MohajonWarm.card,
        border: Border.all(color: MohajonWarm.goldBorder),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: MohajonWarm.ink.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MohajonWarm.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

/// Warm image picker panel matching the Stock card styling.
class _ImagePickerCard extends StatelessWidget {
  const _ImagePickerCard({required this.onTap, this.imagePath});

  final VoidCallback? onTap;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MohajonWarm.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          height: 170,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: MohajonWarm.goldBorder),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: MohajonWarm.ink.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: imagePath != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(19),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AppImage.file(
                        File(imagePath!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _placeholder(context),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: MohajonWarm.primary,
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: MohajonWarm.primary
                                    .withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            color: MohajonWarm.ink,
                            size: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : _placeholder(context),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFE9CF), Color(0xFFFCD9AE)],
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.add_photo_alternate_rounded,
              color: Color(0xFFE98300),
              size: 22,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.t('tapToUploadImage'),
            style: const TextStyle(
              color: MohajonWarm.ink,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l10n.t('clearPhotoHelp'),
            style: const TextStyle(
              color: MohajonWarm.muted,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill chip matching the Stock filter chips.
class _PillChip extends StatelessWidget {
  const _PillChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? MohajonWarm.primary : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? MohajonWarm.primary.withValues(alpha: 0.45)
                  : MohajonWarm.goldBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFF5D4A00) : MohajonWarm.muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
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
        style: const TextStyle(
          color: MohajonWarm.ink,
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
        ),
        children: [
          TextSpan(text: label),
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: MohajonWarm.red),
            ),
        ],
      ),
    );
  }
}

class _ExpiryField extends StatelessWidget {
  const _ExpiryField({required this.value, required this.onChanged});

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5, 12, 31),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = value == null
        ? l10n.t('noExpiryDate')
        : '${value!.day}/${value!.month}/${value!.year}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: l10n.t('expiryDate')),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _pick(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: MohajonWarm.goldBorder),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.event_outlined, size: 18, color: MohajonWarm.ink),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: value == null
                          ? MohajonWarm.ink.withValues(alpha: 0.55)
                          : MohajonWarm.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (value != null)
                  GestureDetector(
                    onTap: () => onChanged(null),
                    child: Icon(Icons.close, size: 16, color: MohajonWarm.red),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
