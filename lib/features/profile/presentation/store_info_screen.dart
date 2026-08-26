import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_error.dart';

import '../../../core/utils/snackbar.dart';
import '../../../core/widgets/action_button.dart';
import '../../../core/app/app_providers.dart';
import '../../settings/providers/shop_profile_providers.dart';
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
  late Profile _currentProfile;

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
    _currentProfile = widget.profile;
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
    if (hash != oldHash) {
      _currentProfile = widget.profile;
      _initControllers();
    }
  }

  void _initControllers() {
    _storeNameController.text = _currentProfile.storeName;
    _ownerNameController.text = _currentProfile.ownerName;
    _phoneController.text = _currentProfile.phone;
    _emailController.text = _currentProfile.email;
    _addressController.text = _currentProfile.address;
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
    final p = _currentProfile;
    final session = ref.watch(authStateProvider).value;
    final canEdit = session?.roles.any((role) =>
            role.toUpperCase() == 'OWNER' || role.toUpperCase() == 'ADMIN') ??
        false;
    final storeName = p.storeName.trim();
    final displayName = storeName.isEmpty ? 'My Store' : storeName;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Store Information'),
        actions: [
          if (canEdit)
            IconButton(
              icon: Icon(_isEditing ? Icons.close : Icons.edit_outlined),
              tooltip: _isEditing ? 'Cancel editing' : 'Edit',
              onPressed: _toggleEdit,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          AnimatedSection(
            child: _StoreHero(
              storeName: displayName,
              ownerName: p.ownerName,
            ),
          ),
          const SizedBox(height: 16),
          AnimatedSection(
            delay: const Duration(milliseconds: 70),
            child: ProfileInfoCard(
              title: 'STORE / BUSINESS',
              children: [
                if (_isEditing) ...[
                  ProfileTextField(
                    label: 'Store Name',
                    controller: _storeNameController,
                    hint: 'Enter store name',
                    prefixIcon: Icons.storefront_rounded,
                    focusNode: _storeNameFocus,
                    nextFocusNode: _ownerNameFocus,
                  ),
                  const SizedBox(height: 16),
                  ProfileTextField(
                    label: 'Owner Name',
                    controller: _ownerNameController,
                    hint: 'Enter owner name',
                    prefixIcon: Icons.person_outline_rounded,
                    focusNode: _ownerNameFocus,
                    nextFocusNode: _phoneFocus,
                  ),
                ] else ...[
                  _InfoTile(
                    icon: Icons.storefront_rounded,
                    color: const Color(0xFFF97316),
                    label: 'Store Name',
                    value: p.storeName,
                  ),
                  const SizedBox(height: 16),
                  _InfoTile(
                    icon: Icons.person_outline_rounded,
                    color: const Color(0xFF0F766E),
                    label: 'Owner Name',
                    value: p.ownerName,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          AnimatedSection(
            delay: const Duration(milliseconds: 130),
            child: ProfileInfoCard(
              title: 'CONTACT INFORMATION',
              children: [
                if (_isEditing) ...[
                  ProfileTextField(
                    label: 'Phone',
                    controller: _phoneController,
                    hint: 'Enter phone number',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    focusNode: _phoneFocus,
                    nextFocusNode: _emailFocus,
                  ),
                  const SizedBox(height: 16),
                  ProfileTextField(
                    label: 'Email',
                    controller: _emailController,
                    hint: 'Enter email address',
                    prefixIcon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    focusNode: _emailFocus,
                    nextFocusNode: _addressFocus,
                  ),
                  const SizedBox(height: 16),
                  ProfileTextField(
                    label: 'Address',
                    controller: _addressController,
                    hint: 'Enter your address',
                    prefixIcon: Icons.location_on_outlined,
                    maxLines: 3,
                    focusNode: _addressFocus,
                    textInputAction: TextInputAction.newline,
                  ),
                ] else ...[
                  _InfoTile(
                    icon: Icons.phone_outlined,
                    color: const Color(0xFF0F766E),
                    label: 'Phone',
                    value: p.phone,
                  ),
                  const SizedBox(height: 16),
                  _InfoTile(
                    icon: Icons.alternate_email_rounded,
                    color: const Color(0xFFB45309),
                    label: 'Email',
                    value: p.email,
                  ),
                  const SizedBox(height: 16),
                  _InfoTile(
                    icon: Icons.location_on_outlined,
                    color: const Color(0xFFDC2626),
                    label: 'Address',
                    value: p.address,
                  ),
                ],
              ],
            ),
          ),
          if (_isEditing && canEdit) ...[
            const SizedBox(height: 24),
            AnimatedSection(
              delay: const Duration(milliseconds: 180),
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
    _storeNameController.text = _currentProfile.storeName;
    _ownerNameController.text = _currentProfile.ownerName;
    _phoneController.text = _currentProfile.phone;
    _emailController.text = _currentProfile.email;
    _addressController.text = _currentProfile.address;
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
      showAppSnackBar(context, errors.first, isError: true);
      return;
    }

    final updated = _currentProfile.copyWith(
      storeName: storeName,
      ownerName: ownerName,
      phone: phone,
      email: email,
      address: address,
    );

    setState(() => _isSaving = true);
    try {
      await ref.read(shopProfileServiceProvider).updateProfile(
            shopName: storeName,
            location: address,
            phoneNumber: phone,
          );
      await ref.read(profileRepositoryProvider).saveProfile(updated);
      ref.read(profileVersionProvider.notifier).state++;
      ref.invalidate(shopProfileProvider);
      if (!mounted) return;
      setState(() {
        _currentProfile = updated;
        _isSaving = false;
        _isEditing = false;
      });
      showAppSnackBar(context, 'Store information updated');
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      showAppSnackBar(context, friendlyErrorMessage(error), isError: true);
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

class _StoreHero extends StatelessWidget {
  const _StoreHero({required this.storeName, required this.ownerName});

  final String storeName;
  final String ownerName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF97316), Color(0xFFC2410C)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC2410C).withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              size: 30,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  storeName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  ownerName.trim().isEmpty
                      ? 'Store Owner'
                      : 'Owned by ${ownerName.trim()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isEmpty = value.trim().isEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isEmpty ? 'Not set' : value,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  color: isEmpty
                      ? colors.onSurfaceVariant.withValues(alpha: 0.5)
                      : colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
