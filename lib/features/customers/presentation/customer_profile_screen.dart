import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/customer.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/snackbar.dart';
import '../../../core/widgets/action_button.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/async_action_state.dart';
import '../providers/customer_providers.dart';

class CustomerProfileScreen extends ConsumerStatefulWidget {
  const CustomerProfileScreen({super.key, required this.customer});

  final Customer customer;

  @override
  ConsumerState<CustomerProfileScreen> createState() =>
      _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends ConsumerState<CustomerProfileScreen>
    with AsyncActionState<CustomerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  String? _imagePath;
  late Customer _customer;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
    _seedControllers(_customer);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _seedControllers(Customer customer) {
    _nameController.text = customer.name;
    _phoneController.text = customer.phone;
    _emailController.text = customer.email;
    _addressController.text = customer.address;
    _notesController.text = customer.notes;
    _imagePath = customer.imagePath;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return withLoadingOverlay(
      Theme(
        data: MohajonWarm.theme(Theme.of(context)),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(l10n.t('clientProfileContact')),
            actions: [
              if (_isEditing)
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: l10n.t('cancel'),
                  onPressed: () {
                    setState(() {
                      _isEditing = false;
                      _seedControllers(_customer);
                    });
                  },
                )
              else
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: l10n.t('edit'),
                  onPressed: () => setState(() => _isEditing = true),
                ),
            ],
          ),
          body: DecoratedBox(
            decoration: const BoxDecoration(gradient: MohajonWarm.pageGradient),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _ProfileHeader(
                    customer: _customer,
                    imagePath: _imagePath,
                    isEditing: _isEditing,
                    onTapImage: _isEditing ? _pickImage : null,
                  ),
                  const SizedBox(height: 6),
                  _InfoRow(
                    icon: Icons.phone_outlined,
                    label: l10n.t('phone'),
                    value: _customer.phone,
                    visible: !_isEditing,
                  ),
                  if (_isEditing) ...[
                    const SizedBox(height: 16),
                    _FieldLabel(label: l10n.t('fullName'), required: true),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.person_outline),
                        hintText: l10n.t('fullNameHint'),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? l10n.t('fieldRequired')
                          : null,
                    ),
                    const SizedBox(height: 14),
                    _FieldLabel(label: l10n.t('phone'), required: true),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.phone_outlined),
                        hintText: l10n.t('phoneHint'),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? l10n.t('fieldRequired')
                          : null,
                    ),
                    const SizedBox(height: 14),
                    _FieldLabel(label: l10n.t('email')),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.email_outlined),
                        hintText: l10n.t('emailHint'),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return null;
                        if (!RegExp(
                          r'^[^@]+@[^@]+\.[^@]+$',
                        ).hasMatch(value.trim())) {
                          return l10n.t('invalidEmail');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _FieldLabel(label: l10n.t('address')),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _addressController,
                      maxLines: 1,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        hintText: l10n.t('addressHint'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _FieldLabel(label: l10n.t('notes')),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 5,
                      maxLength: 300,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 80),
                          child: Icon(Icons.notes_outlined),
                        ),
                        hintText: l10n.t('specialNotesHint'),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${_notesController.text.length}/300',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ActionButton(
                      onPressed: _saveCustomer,
                      isBusy: isBusy,
                      icon: Icons.save_outlined,
                      label: l10n.t('updateClient'),
                      busyLabel: l10n.t('savingCustomer'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      label: l10n.t('savingCustomer'),
    );
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.transparent,
      builder: (ctx) => Theme(
        data: MohajonWarm.theme(Theme.of(context)),
        child: Container(
          decoration: const BoxDecoration(
            gradient: MohajonWarm.pageGradient,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
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
                    AppLocalizations.of(context).t('profilePhoto'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.camera_alt_outlined),
                    title: Text(AppLocalizations.of(context).t('takePhoto')),
                    onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_library_outlined),
                    title: Text(
                      AppLocalizations.of(context).t('chooseFromGallery'),
                    ),
                    onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() => _imagePath = picked.path);
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          AppLocalizations.of(context).t('couldNotPickImage'),
          isError: true,
        );
      }
    }
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    await runBusyAction(() async {
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      await ref
          .read(customerServiceProvider)
          .save(
            customerId: _customer.customerId,
            name: name,
            phone: phone,
            email: _emailController.text.trim(),
            address: _addressController.text.trim(),
            notes: _notesController.text.trim(),
            imagePath: _imagePath,
          );
      if (!mounted) return;
      setState(() {
        _customer = _customer.copyWith(
          name: name,
          phone: phone,
          email: _emailController.text.trim(),
          address: _addressController.text.trim(),
          notes: _notesController.text.trim(),
          imagePath: _imagePath,
        );
        _isEditing = false;
      });
      showAppSnackBar(
        context,
        AppLocalizations.of(context).t('customerUpdated'),
      );
    });
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.customer,
    required this.imagePath,
    required this.isEditing,
    this.onTapImage,
  });

  final Customer customer;
  final String? imagePath;
  final bool isEditing;
  final VoidCallback? onTapImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: MohajonWarm.card.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MohajonWarm.goldBorder),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onTapImage,
            child: Stack(
              children: [
                _AvatarWidget(name: customer.name, imagePath: imagePath),
                if (isEditing)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: MohajonWarm.ink,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: MohajonWarm.primary,
                        size: 18,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            customer.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            customer.phone,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarWidget extends StatelessWidget {
  const _AvatarWidget({required this.name, this.imagePath});

  final String name;
  final String? imagePath;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || name.trim().isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    const size = 100.0;

    if (imagePath != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: MohajonWarm.goldBorder, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size / 2),
          child: AppImage.file(
            File(imagePath!),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, stk) => _initialsAvatar(size),
          ),
        ),
      );
    }

    return _initialsAvatar(size);
  }

  Widget _initialsAvatar(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: MohajonWarm.tintYellow,
        shape: BoxShape.circle,
        border: Border.all(color: MohajonWarm.goldBorder, width: 2),
      ),
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(
            color: MohajonWarm.goldText,
            fontSize: 32,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.visible = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: MohajonWarm.card.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: MohajonWarm.goldBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: MohajonWarm.tintYellow,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: MohajonWarm.goldText),
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
                    color: MohajonWarm.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
        ],
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
