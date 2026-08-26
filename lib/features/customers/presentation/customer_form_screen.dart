import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_error.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/customer.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/snackbar.dart';
import '../../../core/widgets/action_button.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/async_action_state.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';
import '../providers/customer_providers.dart';

class CustomerFormScreen extends ConsumerStatefulWidget {
  const CustomerFormScreen({super.key, this.customer});

  final Customer? customer;

  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen>
    with AsyncActionState<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();

  String? _imagePath;

  @override
  void initState() {
    super.initState();
    final customer = widget.customer;
    if (customer != null) {
      _name.text = customer.name;
      _phone.text = customer.phone;
      _email.text = customer.email;
      _address.text = customer.address;
      _notes.text = customer.notes;
      _imagePath = customer.imagePath;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  String get _initials {
    final name = _name.text.trim();
    if (name.isEmpty) return '';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.customer != null;
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
                            padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                            children: [
                              _FormHeader(
                                title: isEditing ? 'Edit Client' : 'Add Client',
                                subtitle: 'Client profile & contact',
                                icon: Icons.people_alt_rounded,
                                onBack: () =>
                                    Navigator.of(context).maybePop(),
                              ),
                              const SizedBox(height: 18),
                              _ProfilePhoto(
                                imagePath: _imagePath,
                                initials: _initials,
                                onTap: isBusy ? null : _pickImage,
                              ),
                              const SizedBox(height: 18),
                              _SectionCard(
                                icon: Icons.person_outline_rounded,
                                iconColor: MohajonWarm.goldText,
                                iconBackground: MohajonWarm.tintYellow,
                                title: 'Personal Details',
                                children: [
                                  const _FieldLabel(
                                    label: 'Full Name',
                                    required: true,
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _name,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    onChanged: (_) => setState(() {}),
                                    decoration: const InputDecoration(
                                      prefixIcon: Icon(
                                        Icons.person_outline_rounded,
                                        size: 20,
                                        color: MohajonWarm.muted,
                                      ),
                                      hintText: 'e.g. Rahim Uddin',
                                    ),
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                        ? 'Required'
                                        : null,
                                  ),
                                  const SizedBox(height: 14),
                                  const _FieldLabel(
                                    label: 'Phone',
                                    required: true,
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _phone,
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(13),
                                    ],
                                    decoration: const InputDecoration(
                                      prefixIcon: Icon(
                                        Icons.phone_outlined,
                                        size: 20,
                                        color: MohajonWarm.muted,
                                      ),
                                      hintText: 'e.g. 01711-234567',
                                    ),
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                        ? 'Required'
                                        : null,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _SectionCard(
                                icon: Icons.location_on_outlined,
                                iconColor: MohajonWarm.green,
                                iconBackground: MohajonWarm.tintGreen,
                                title: 'Contact Information',
                                children: [
                                  const _FieldLabel(label: 'Email'),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _email,
                                    keyboardType: TextInputType.emailAddress,
                                    autocorrect: false,
                                    decoration: const InputDecoration(
                                      prefixIcon: Icon(
                                        Icons.email_outlined,
                                        size: 20,
                                        color: MohajonWarm.muted,
                                      ),
                                      hintText: 'e.g. rahim@example.com',
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return null;
                                      }
                                      if (!RegExp(
                                        r'^[^@]+@[^@]+\.[^@]+$',
                                      ).hasMatch(value.trim())) {
                                        return 'Invalid email';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  const _FieldLabel(label: 'Address'),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _address,
                                    maxLines: 1,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    decoration: const InputDecoration(
                                      prefixIcon: Icon(
                                        Icons.location_on_outlined,
                                        size: 20,
                                        color: MohajonWarm.muted,
                                      ),
                                      hintText: 'e.g. 12/A Mirpur Road, Dhaka',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _SectionCard(
                                icon: Icons.notes_outlined,
                                iconColor: MohajonWarm.orange,
                                iconBackground: MohajonWarm.tintOrange,
                                title: 'Notes',
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: MohajonWarm.primary.withValues(
                                      alpha: 0.22,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: MohajonWarm.primary.withValues(
                                        alpha: 0.35,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    '${_notes.text.length}/300',
                                    style: const TextStyle(
                                      color: Color(0xFF5D4A00),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                children: [
                                  TextFormField(
                                    controller: _notes,
                                    maxLines: 5,
                                    maxLength: 300,
                                    onChanged: (_) => setState(() {}),
                                    decoration: const InputDecoration(
                                      hintText:
                                          'Any special notes about this client...',
                                      counterText: '',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: MohajonWarm.tintYellow,
                                  border: Border.all(
                                    color: MohajonWarm.goldBorder,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      color: MohajonWarm.goldText,
                                      size: 18,
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'New clients start with zero dues and zero visits. Their purchase history will update automatically as you add sales.',
                                        style: TextStyle(
                                          color: Color(0xFF5D4A00),
                                          fontSize: 12,
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
                        ),
                      ),
                      _SaveBar(
                        child: ActionButton(
                          onPressed: _saveCustomer,
                          isBusy: isBusy,
                          icon: Icons.save_outlined,
                          label: isEditing ? 'Update Client' : 'Save Client',
                          busyLabel: isEditing ? 'Updating...' : 'Saving...',
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
      label: 'Saving customer...',
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

  Future<void> _pickImage() async {
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
              const Text(
                'Profile Photo',
                style: TextStyle(
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
                title: const Text(
                  'Take a photo',
                  style: TextStyle(
                    color: MohajonWarm.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: MohajonWarm.goldText,
                ),
                title: const Text(
                  'Choose from gallery',
                  style: TextStyle(
                    color: MohajonWarm.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
            ],
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
        showAppSnackBar(context, 'Could not pick image', isError: true);
      }
    }
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await runBusyAction(() async {
        await ref
            .read(customerServiceProvider)
            .save(
              customerId: widget.customer?.customerId,
              name: _name.text.trim(),
              phone: _phone.text.trim(),
              email: _email.text.trim(),
              address: _address.text.trim(),
              notes: _notes.text.trim(),
              imagePath: _imagePath,
            );
        if (mounted) Navigator.of(context).pop();
      });
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, friendlyErrorMessage(error), isError: true);
      }
    }
  }
}

/// Pinned bottom bar so the save action is always reachable.
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
    required this.icon,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final IconData icon;
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
          child: Icon(icon, color: MohajonWarm.ink, size: 17),
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
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final List<Widget> children;
  final Widget? trailing;

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
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _ProfilePhoto extends StatelessWidget {
  const _ProfilePhoto({
    required this.imagePath,
    required this.initials,
    required this.onTap,
  });

  final String? imagePath;
  final String initials;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const size = 100.0;

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: size + 12,
              height: size + 12,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [MohajonWarm.primary, MohajonWarm.primaryPale],
                ),
                boxShadow: [
                  BoxShadow(
                    color: MohajonWarm.primary.withValues(alpha: 0.30),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Container(
                    width: size,
                    height: size,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: imagePath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(size / 2),
                            child: AppImage.file(
                              File(imagePath!),
                              width: size,
                              height: size,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stk) =>
                                  _defaultAvatar(),
                            ),
                          )
                        : _defaultAvatar(),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: MohajonWarm.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: MohajonWarm.primary.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.photo_camera_rounded,
                        color: MohajonWarm.ink,
                        size: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: MohajonWarm.tintYellow,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: MohajonWarm.goldBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  imagePath != null
                      ? Icons.check_circle_rounded
                      : Icons.touch_app_rounded,
                  size: 13,
                  color: MohajonWarm.goldText,
                ),
                const SizedBox(width: 6),
                Text(
                  imagePath != null
                      ? 'Photo added — tap to change'
                      : 'Tap to add profile photo',
                  style: const TextStyle(
                    color: Color(0xFF5D4A00),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _defaultAvatar() {
    return Center(
      child: initials.isEmpty
          ? const Icon(
              Icons.person_rounded,
              size: 46,
              color: MohajonWarm.goldText,
            )
          : Text(
              initials,
              style: const TextStyle(
                color: MohajonWarm.goldText,
                fontSize: 30,
                fontWeight: FontWeight.w900,
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
