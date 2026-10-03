import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/app_error.dart';
import '../../../core/utils/snackbar.dart';
import '../../../core/widgets/action_button.dart';
import '../../../core/widgets/app_image.dart';
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
  final _tinController = TextEditingController();
  final _binController = TextEditingController();

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
      widget.profile.tin,
      widget.profile.bin,
    );
    final oldHash = Object.hash(
      oldWidget.profile.storeName,
      oldWidget.profile.ownerName,
      oldWidget.profile.phone,
      oldWidget.profile.email,
      oldWidget.profile.address,
      oldWidget.profile.tin,
      oldWidget.profile.bin,
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
    _tinController.dispose();
    _binController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _currentProfile;
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(authStateProvider).value;
    final canEdit = session?.roles.any((role) =>
            role.toUpperCase() == 'OWNER' || role.toUpperCase() == 'ADMIN') ??
        false;
    final storeName = p.storeName.trim();
    final displayName = storeName.isEmpty ? l10n.t('myStore') : storeName;

    return Theme(
      data: MohajonWarm.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: MohajonWarm.pageGradient),
          child: SafeArea(
            child: Column(
              children: [
                _StoreInfoHeader(
                  title: l10n.t('storeInformation'),
                  subtitle: l10n.t('shopProfile'),
                  isEditing: _isEditing,
                  canEdit: canEdit,
                  onBack: () => Navigator.of(context).pop(),
                  onEdit: _toggleEdit,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                    children: [
                      AnimatedSection(
                        child: _StoreHero(
                          storeName: displayName,
                          ownerName: p.ownerName,
                          imagePath: p.imagePath,
                        ),
                      ),
                      const SizedBox(height: 16),
                      AnimatedSection(
                        delay: const Duration(milliseconds: 70),
                        child: ProfileInfoCard(
                          title: l10n.t('storeBusiness'),
                          icon: Icons.storefront_rounded,
                          accentColor: MohajonWarm.orange,
                          children: [
                            if (_isEditing) ...[
                              ProfileTextField(
                                label: l10n.t('storeName'),
                                controller: _storeNameController,
                                hint: l10n.t('enterStoreName'),
                                prefixIcon: Icons.storefront_rounded,
                                focusNode: _storeNameFocus,
                                nextFocusNode: _ownerNameFocus,
                              ),
                              const SizedBox(height: 14),
                              ProfileTextField(
                                label: l10n.t('ownerName'),
                                controller: _ownerNameController,
                                hint: l10n.t('enterOwnerName'),
                                prefixIcon: Icons.person_outline_rounded,
                                focusNode: _ownerNameFocus,
                                nextFocusNode: _phoneFocus,
                              ),
                            ] else ...[
                              _InfoTile(
                                icon: Icons.storefront_rounded,
                                color: MohajonWarm.orange,
                                label: l10n.t('storeName'),
                                value: p.storeName,
                              ),
                              const SizedBox(height: 14),
                              _InfoTile(
                                icon: Icons.person_outline_rounded,
                                color: MohajonWarm.green,
                                label: l10n.t('ownerName'),
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
                          title: l10n.t('contactInformationUppercase'),
                          icon: Icons.contact_mail_outlined,
                          accentColor: MohajonWarm.green,
                          children: [
                            if (_isEditing) ...[
                              ProfileTextField(
                                label: l10n.t('phone'),
                                controller: _phoneController,
                                hint: l10n.t('enterPhoneNumber'),
                                prefixIcon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                                focusNode: _phoneFocus,
                                nextFocusNode: _emailFocus,
                              ),
                              const SizedBox(height: 14),
                              ProfileTextField(
                                label: l10n.t('email'),
                                controller: _emailController,
                                hint: l10n.t('enterEmailAddress'),
                                prefixIcon: Icons.alternate_email_rounded,
                                keyboardType: TextInputType.emailAddress,
                                focusNode: _emailFocus,
                                nextFocusNode: _addressFocus,
                              ),
                              const SizedBox(height: 14),
                              ProfileTextField(
                                label: l10n.t('address'),
                                controller: _addressController,
                                hint: l10n.t('enterAddress'),
                                prefixIcon: Icons.location_on_outlined,
                                maxLines: 3,
                                focusNode: _addressFocus,
                                textInputAction: TextInputAction.newline,
                              ),
                              const SizedBox(height: 14),
                              ProfileTextField(
                                label: l10n.t('tinNumber'),
                                controller: _tinController,
                                hint: l10n.t('tinHint'),
                                prefixIcon: Icons.receipt_long_outlined,
                              ),
                              const SizedBox(height: 14),
                              ProfileTextField(
                                label: l10n.t('binNumber'),
                                controller: _binController,
                                hint: l10n.t('binHint'),
                                prefixIcon: Icons.business_center_outlined,
                              ),
                            ] else ...[
                              _InfoTile(
                                icon: Icons.phone_outlined,
                                color: MohajonWarm.green,
                                label: l10n.t('phone'),
                                value: p.phone,
                              ),
                              const SizedBox(height: 14),
                              _InfoTile(
                                icon: Icons.alternate_email_rounded,
                                color: MohajonWarm.goldText,
                                label: l10n.t('email'),
                                value: p.email,
                              ),
                              const SizedBox(height: 14),
                              _InfoTile(
                                icon: Icons.location_on_outlined,
                                color: MohajonWarm.red,
                                label: l10n.t('address'),
                                value: p.address,
                              ),
                              const SizedBox(height: 14),
                              _InfoTile(
                                icon: Icons.receipt_long_outlined,
                                color: MohajonWarm.orange,
                                label: l10n.t('tinNumber'),
                                value: p.tin,
                              ),
                              const SizedBox(height: 14),
                              _InfoTile(
                                icon: Icons.business_center_outlined,
                                color: MohajonWarm.green,
                                label: l10n.t('binNumber'),
                                value: p.bin,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (_isEditing && canEdit) ...[
                        const SizedBox(height: 24),
                        AnimatedSection(
                          delay: const Duration(milliseconds: 180),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              filledButtonTheme: FilledButtonThemeData(
                                style: FilledButton.styleFrom(
                                  backgroundColor: MohajonWarm.ink,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor:
                                      MohajonWarm.muted.withValues(alpha: 0.5),
                                  disabledForegroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                            child: ActionButton(
                              onPressed: _saveProfile,
                              isBusy: _isSaving,
                              icon: Icons.save_rounded,
                              label: l10n.t('saveChanges'),
                              busyLabel: l10n.t('savingDots'),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
    _tinController.text = _currentProfile.tin;
    _binController.text = _currentProfile.bin;
  }

  Future<void> _saveProfile() async {
    final l10n = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();

    final storeName = _storeNameController.text;
    final ownerName = _ownerNameController.text;
    final phone = _phoneController.text;
    final email = _emailController.text;
    final address = _addressController.text;
    final tin = _tinController.text;
    final bin = _binController.text;

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
      tin: tin,
      bin: bin,
    );

    setState(() => _isSaving = true);
    try {
      await ref.read(shopProfileServiceProvider).updateProfile(
            shopName: storeName,
            location: address,
            phoneNumber: phone,
            tin: tin,
            bin: bin,
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
      showAppSnackBar(context, l10n.t('storeInformationUpdated'));
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      showAppSnackBar(context, friendlyErrorMessage(error), isError: true);
    }
  }

  List<String> _validate(String storeName, String ownerName, String phone, String email, String address) {
    final l10n = AppLocalizations.of(context);
    final errors = <String>[];
    if (storeName.trim().isEmpty) {
      errors.add(l10n.t('storeNameRequired'));
    }
    if (ownerName.trim().isEmpty) {
      errors.add(l10n.t('ownerNameRequired'));
    }
    if (phone.trim().isEmpty) {
      errors.add(l10n.t('phoneNumberRequired'));
    } else if (!RegExp(r'^\+?[\d\s\-()]{7,20}$').hasMatch(phone.trim())) {
      errors.add(l10n.t('validPhoneNumber'));
    }
    if (email.trim().isEmpty) {
      errors.add(l10n.t('emailIsRequired'));
    } else if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim())) {
      errors.add(l10n.t('validEmailAddress'));
    }
    if (address.trim().isEmpty) {
      errors.add(l10n.t('addressRequired'));
    }
    return errors;
  }
}

class _StoreInfoHeader extends StatelessWidget {
  const _StoreInfoHeader({
    required this.title,
    required this.subtitle,
    required this.isEditing,
    required this.canEdit,
    required this.onBack,
    required this.onEdit,
  });

  final String title;
  final String subtitle;
  final bool isEditing;
  final bool canEdit;
  final VoidCallback onBack;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [MohajonWarm.primary, MohajonWarm.primaryPale],
              ),
              borderRadius: BorderRadius.circular(11),
              boxShadow: [
                BoxShadow(
                  color: MohajonWarm.primary.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: MohajonWarm.ink,
              size: 19,
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
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: MohajonWarm.muted,
                  ),
                ),
              ],
            ),
          ),
          if (canEdit) ...[
            const SizedBox(width: 8),
            _EditPill(isEditing: isEditing, onTap: onEdit),
          ],
        ],
      ),
    );
  }
}

class _EditPill extends StatelessWidget {
  const _EditPill({required this.isEditing, required this.onTap});

  final bool isEditing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final Gradient? backgroundGradient = isEditing
        ? null
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [MohajonWarm.primary, MohajonWarm.primarySoft],
          );

    return Material(
      color: isEditing ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            gradient: backgroundGradient,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: isEditing ? MohajonWarm.goldBorder : Colors.transparent,
            ),
            boxShadow: isEditing
                ? null
                : [
                    BoxShadow(
                      color: MohajonWarm.primary.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isEditing ? Icons.close_rounded : Icons.edit_rounded,
                size: 15,
                color: isEditing ? MohajonWarm.red : MohajonWarm.ink,
              ),
              const SizedBox(width: 6),
              Text(
                isEditing ? l10n.t('cancelEditing') : l10n.t('editAction'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isEditing ? MohajonWarm.red : MohajonWarm.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreHero extends StatelessWidget {
  const _StoreHero({
    required this.storeName,
    required this.ownerName,
    required this.imagePath,
  });

  final String storeName;
  final String ownerName;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ownerLine = ownerName.trim().isEmpty
        ? l10n.t('storeOwner')
        : l10n.tP('ownedBy', {'name': ownerName.trim()});

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MohajonWarm.primary,
            MohajonWarm.primarySoft,
            MohajonWarm.primaryPale,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: MohajonWarm.primary.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -45,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
            ),
          ),
          Positioned(
            left: -24,
            bottom: -40,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.13),
              ),
            ),
          ),
          Positioned(
            right: 70,
            bottom: -16,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: MohajonWarm.goldBorder, width: 1.4),
                        boxShadow: [
                          BoxShadow(
                            color: MohajonWarm.ink.withValues(alpha: 0.12),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: (imagePath ?? '').trim().isEmpty
                          ? const Icon(
                              Icons.storefront_rounded,
                              color: MohajonWarm.orange,
                              size: 32,
                            )
                          : AppImage(
                              path: imagePath!,
                              width: 68,
                              height: 68,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stk) => const Icon(
                                Icons.storefront_rounded,
                                color: MohajonWarm.orange,
                                size: 32,
                              ),
                            ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 23,
                        height: 23,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [MohajonWarm.primary, MohajonWarm.primaryPale],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          color: MohajonWarm.ink,
                          size: 13,
                        ),
                      ),
                    ),
                  ],
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
                          color: MohajonWarm.ink,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: MohajonWarm.tintYellow,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: MohajonWarm.goldBorder,
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified_rounded,
                              size: 13,
                              color: MohajonWarm.goldText,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                ownerLine,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: MohajonWarm.ink,
                                ),
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
    final l10n = AppLocalizations.of(context);
    final isEmpty = value.trim().isEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
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
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: MohajonWarm.muted,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                isEmpty ? l10n.t('notSet') : value,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  color: isEmpty
                      ? MohajonWarm.muted.withValues(alpha: 0.5)
                      : MohajonWarm.ink,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
