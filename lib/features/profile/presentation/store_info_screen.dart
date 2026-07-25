import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/action_button.dart';
import '../models/profile.dart';
import '../providers/profile_providers.dart';
import 'widgets/animated_section.dart';
import 'widgets/profile_info_card.dart';
import 'widgets/profile_text_field.dart';

class StoreInfoScreen extends ConsumerStatefulWidget {
  const StoreInfoScreen({super.key, required this.profile});

  final Profile profile;

  @override
  ConsumerState<StoreInfoScreen> createState() => _StoreInfoScreenState();
}

class _StoreInfoScreenState extends ConsumerState<StoreInfoScreen> {
  bool _isEditing = false;

  final _storeNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();

  final _storeNameFocus = FocusNode();
  final _ownerNameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _addressFocus = FocusNode();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void didUpdateWidget(StoreInfoScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hash = Object.hash(
      widget.profile.storeName,
      widget.profile.ownerName,
      widget.profile.phone,
      widget.profile.email,
      widget.profile.address,
    );
    final oldHash = Object.hash(
      oldWidget.profile.storeName,
      oldWidget.profile.ownerName,
      oldWidget.profile.phone,
      oldWidget.profile.email,
      oldWidget.profile.address,
    );
    if (hash != oldHash) _initControllers();
  }

  void _initControllers() {
    _storeNameController.text = widget.profile.storeName;
    _ownerNameController.text = widget.profile.ownerName;
    _phoneController.text = widget.profile.phone;
    _emailController.text = widget.profile.email;
    _addressController.text = widget.profile.address;
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _storeNameFocus.dispose();
    _ownerNameFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _addressFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final p = widget.profile;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Store Information'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit_outlined),
            tooltip: _isEditing ? 'Cancel editing' : 'Edit',
            onPressed: _toggleEdit,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          AnimatedSection(
            child: ProfileInfoCard(
              title: 'STORE / BUSINESS',
              children: [
                if (_isEditing) ...[
                  ProfileTextField(
                    label: 'Store Name',
                    controller: _storeNameController,
                    hint: 'Enter store name',
                    focusNode: _storeNameFocus,
                    nextFocusNode: _ownerNameFocus,
                  ),
                  const SizedBox(height: 16),
                  ProfileTextField(
                    label: 'Owner Name',
                    controller: _ownerNameController,
                    hint: 'Enter owner name',
                    focusNode: _ownerNameFocus,
                    nextFocusNode: _phoneFocus,
                  ),
                ] else ...[
                  _InfoRow(label: 'Store Name', value: p.storeName),
                  const SizedBox(height: 12),
                  _InfoRow(label: 'Owner Name', value: p.ownerName),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          AnimatedSection(
            delay: const Duration(milliseconds: 80),
            child: ProfileInfoCard(
              title: 'CONTACT INFORMATION',
              children: [
                if (_isEditing) ...[
                  ProfileTextField(
                    label: 'Phone',
                    controller: _phoneController,
                    hint: 'Enter phone number',
                    keyboardType: TextInputType.phone,
                    focusNode: _phoneFocus,
                    nextFocusNode: _emailFocus,
                  ),
                  const SizedBox(height: 16),
                  ProfileTextField(
                    label: 'Email',
                    controller: _emailController,
                    hint: 'Enter email address',
                    keyboardType: TextInputType.emailAddress,
                    focusNode: _emailFocus,
                    nextFocusNode: _addressFocus,
                  ),
                  const SizedBox(height: 16),
                  ProfileTextField(
                    label: 'Address',
                    controller: _addressController,
                    hint: 'Enter your address',
                    maxLines: 3,
                    focusNode: _addressFocus,
                    textInputAction: TextInputAction.newline,
                  ),
                ] else ...[
                  _InfoRow(label: 'Phone', value: p.phone),
                  const SizedBox(height: 12),
                  _InfoRow(label: 'Email', value: p.email),
                  const SizedBox(height: 12),
                  _InfoRow(label: 'Address', value: p.address),
                ],
              ],
            ),
          ),
          if (_isEditing) ...[
            const SizedBox(height: 24),
            AnimatedSection(
              delay: const Duration(milliseconds: 120),
              child: ActionButton(
                onPressed: _saveProfile,
                isBusy: _isSaving,
                icon: Icons.save_rounded,
                label: 'Save Changes',
                busyLabel: 'Saving...',
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _toggleEdit() {
    if (_isEditing) {
      _resetControllers();
    }
    setState(() => _isEditing = !_isEditing);
  }

  void _resetControllers() {
    _storeNameController.text = widget.profile.storeName;
    _ownerNameController.text = widget.profile.ownerName;
    _phoneController.text = widget.profile.phone;
    _emailController.text = widget.profile.email;
    _addressController.text = widget.profile.address;
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();

    final storeName = _storeNameController.text;
    final ownerName = _ownerNameController.text;
    final phone = _phoneController.text;
    final email = _emailController.text;
    final address = _addressController.text;

    final errors = _validate(storeName, ownerName, phone, email, address);
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errors.first),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return;
    }

    final updated = widget.profile.copyWith(
      storeName: storeName,
      ownerName: ownerName,
      phone: phone,
      email: email,
      address: address,
    );

    setState(() => _isSaving = true);
    try {
      await ref.read(profileRepositoryProvider).saveProfile(updated);
      ref.read(profileVersionProvider.notifier).state++;
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Store information updated'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<String> _validate(String storeName, String ownerName, String phone, String email, String address) {
    final errors = <String>[];
    if (storeName.trim().isEmpty) {
      errors.add('Store name is required');
    }
    if (ownerName.trim().isEmpty) {
      errors.add('Owner name is required');
    }
    if (phone.trim().isEmpty) {
      errors.add('Phone number is required');
    } else if (!RegExp(r'^\+?[\d\s\-()]{7,20}$').hasMatch(phone.trim())) {
      errors.add('Enter a valid phone number');
    }
    if (email.trim().isEmpty) {
      errors.add('Email is required');
    } else if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim())) {
      errors.add('Enter a valid email address');
    }
    if (address.trim().isEmpty) {
      errors.add('Address is required');
    }
    return errors;
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isEmpty = value.trim().isEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            isEmpty ? 'Not set' : value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: isEmpty
                  ? colors.onSurfaceVariant.withValues(alpha: 0.5)
                  : colors.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
