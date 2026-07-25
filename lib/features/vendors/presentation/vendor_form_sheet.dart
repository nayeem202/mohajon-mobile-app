import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/action_button.dart';
import '../../../core/widgets/async_action_state.dart';
import '../models/vendor.dart';
import '../providers/vendor_providers.dart';

class VendorFormSheet extends ConsumerStatefulWidget {
  const VendorFormSheet({super.key, this.vendor});

  final Vendor? vendor;

  @override
  ConsumerState<VendorFormSheet> createState() => _VendorFormSheetState();
}

class _VendorFormSheetState extends ConsumerState<VendorFormSheet>
    with AsyncActionState<VendorFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _companyCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _productsCtrl = TextEditingController();

  String _category = '';
  double _rating = 0;

  @override
  void initState() {
    super.initState();
    final vendor = widget.vendor;
    if (vendor != null) {
      _companyCtrl.text = vendor.companyName;
      _contactCtrl.text = vendor.contactPerson;
      _phoneCtrl.text = vendor.phone;
      _emailCtrl.text = vendor.email;
      _addressCtrl.text = vendor.address;
      _productsCtrl.text = vendor.products;
      _category = vendor.category;
      _rating = vendor.rating;
    }
  }

  @override
  void dispose() {
    _companyCtrl.dispose();
    _contactCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _productsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.vendor != null;
    final colors = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Form(
            key: _formKey,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isEditing ? Icons.edit_rounded : Icons.store_rounded,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEditing ? 'Edit Vendor' : 'Add Vendor',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _FieldLabel(label: 'Company Name', required: true),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _companyCtrl,
                  decoration: const InputDecoration(hintText: 'e.g. Fresh Foods Ltd.'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                _FieldLabel(label: 'Contact Person', required: true),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _contactCtrl,
                  decoration: const InputDecoration(hintText: 'e.g. Rahim Uddin'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                _FieldLabel(label: 'Phone', required: true),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(hintText: 'e.g. +880 1711-234567'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Required';
                    final phone = value.trim();
                    if (phone.length < 10) return 'Invalid phone number';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _FieldLabel(label: 'Email'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'e.g. contact@company.com'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value.trim())) {
                      return 'Invalid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _FieldLabel(label: 'Category'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _category.isEmpty ? null : _category,
                  decoration: const InputDecoration(hintText: 'Select category'),
                  items: vendorCategories.map((cat) {
                    return DropdownMenuItem(value: cat, child: Text(cat));
                  }).toList(),
                  onChanged: (v) => setState(() => _category = v ?? ''),
                ),
                const SizedBox(height: 14),
                _FieldLabel(label: 'Address'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _addressCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(hintText: 'e.g. 12/A Mirpur Road, Dhaka'),
                ),
                const SizedBox(height: 14),
                _FieldLabel(label: 'Products Supplied'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _productsCtrl,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Rice, Lentils, Spices',
                    helperText: 'Separate with commas',
                  ),
                ),
                const SizedBox(height: 14),
                _FieldLabel(label: 'Rating'),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(5, (index) {
                    final starVal = index + 1;
                    return IconButton(
                      onPressed: () => setState(() => _rating = starVal.toDouble()),
                      icon: Icon(
                        index < _rating.floor()
                            ? Icons.star_rounded
                            : (index < _rating.ceil() && _rating - index >= 0.5
                                ? Icons.star_half_rounded
                                : Icons.star_outline_rounded),
                        color: const Color(0xFFF59E0B),
                        size: 32,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),
                ActionButton(
                  onPressed: _save,
                  isBusy: isBusy,
                  icon: Icons.save_outlined,
                  label: isEditing ? 'Update Vendor' : 'Save Vendor',
                  busyLabel: isEditing ? 'Updating...' : 'Saving...',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final vendors = ref.read(vendorsProvider).value ?? const <Vendor>[];
    final duplicate = vendors.any((v) {
      if (widget.vendor != null && v.vendorId == widget.vendor!.vendorId) return false;
      return v.companyName.toLowerCase() == _companyCtrl.text.trim().toLowerCase();
    });
    if (duplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A vendor with this company name already exists')),
      );
      return;
    }

    await runBusyAction(() async {
      await ref.read(vendorServiceProvider).save(
        vendorId: widget.vendor?.vendorId,
        companyName: _companyCtrl.text.trim(),
        contactPerson: _contactCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        category: _category,
        address: _addressCtrl.text.trim(),
        products: _productsCtrl.text.trim(),
        rating: _rating,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.vendor != null ? 'Vendor updated' : 'Vendor added'),
          ),
        );
      }
    });
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
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        children: [
          TextSpan(text: label),
          if (required)
            TextSpan(
              text: ' *',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }
}
