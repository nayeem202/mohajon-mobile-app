import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_error.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/widgets/action_button.dart';
import '../../../core/widgets/async_action_state.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';
import '../models/investor.dart';
import '../providers/investor_providers.dart';

class InvestorFormScreen extends ConsumerStatefulWidget {
  const InvestorFormScreen({super.key, this.investor});

  final Investor? investor;

  @override
  ConsumerState<InvestorFormScreen> createState() =>
      _InvestorFormScreenState();
}

class _InvestorFormScreenState extends ConsumerState<InvestorFormScreen>
    with AsyncActionState<InvestorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _picker = ImagePicker();
  File? _photo;

  bool get isEditing => widget.investor != null;

  @override
  void initState() {
    super.initState();
    final investor = widget.investor;
    _nameCtrl.text = investor?.name ?? '';
    _phoneCtrl.text = investor?.phone ?? '';
    _emailCtrl.text = investor?.email ?? '';
    _addressCtrl.text = investor?.address ?? '';
    _notesCtrl.text = investor?.notes ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final investor = widget.investor;
    final l10n = AppLocalizations.of(context);
    return withLoadingOverlay(
      Theme(
        data: MohajonWarm.theme(Theme.of(context)),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: MohajonWarm.pageGradient,
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -70,
                  right: -50,
                  child: IgnorePointer(
                    child: Container(
                      width: 190,
                      height: 190,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 34,
                  right: 96,
                  child: IgnorePointer(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 110,
                  left: -60,
                  child: IgnorePointer(
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      Expanded(
                        child: Form(
                          key: _formKey,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(
                              18,
                              12,
                              18,
                              16,
                            ),
                            children: [
                              _FormHeader(
                                title: isEditing
                                    ? l10n.t('editInvestor')
                                    : l10n.t('addInvestor'),
                                subtitle: l10n.t('capitalPartners'),
                                onBack: () =>
                                    Navigator.of(context).maybePop(),
                              ),
                              const SizedBox(height: 18),
                              _PhotoPicker(
                                photo: _photo,
                                photoUrl: investor?.photoUrl ?? '',
                                name: _nameCtrl.text,
                                onTap: isBusy ? null : _pickImage,
                              ),
                              const SizedBox(height: 18),
                              _SectionCard(
                                icon: Icons.badge_outlined,
                                iconColor: MohajonWarm.goldText,
                                iconBackground: MohajonWarm.tintYellow,
                                title: l10n.t('investorDetails'),
                                children: [
                                  _FieldLabel(
                                    label: l10n.t('fullName'),
                                    required: true,
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _nameCtrl,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    onChanged: (_) => setState(() {}),
                                    decoration:
                                        InputDecoration(
                                      prefixIcon: Icon(
                                        Icons.person_outline_rounded,
                                        size: 20,
                                        color: MohajonWarm.muted,
                                      ),
                                      hintText: l10n.t('fullNameHint'),
                                    ),
                                    validator: (value) =>
                                        value == null ||
                                            value.trim().isEmpty
                                        ? l10n.t('pleaseEnterFullName')
                                        : null,
                                  ),
                                  const SizedBox(height: 14),
                                  _FieldLabel(label: l10n.t('phone')),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _phoneCtrl,
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [
                                      FilteringTextInputFormatter
                                          .digitsOnly,
                                      LengthLimitingTextInputFormatter(
                                        13,
                                      ),
                                    ],
                                    decoration:
                                        InputDecoration(
                                      prefixIcon: Icon(
                                        Icons.phone_outlined,
                                        size: 20,
                                        color: MohajonWarm.muted,
                                      ),
                                      hintText: l10n.t('phoneHint'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _SectionCard(
                                icon: Icons.location_on_outlined,
                                iconColor: MohajonWarm.green,
                                iconBackground: MohajonWarm.tintGreen,
                                title: l10n.t('contactInformation'),
                                children: [
                                  _FieldLabel(label: l10n.t('email')),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _emailCtrl,
                                    keyboardType: TextInputType
                                        .emailAddress,
                                    autocorrect: false,
                                    decoration:
                                        InputDecoration(
                                      prefixIcon: Icon(
                                        Icons.email_outlined,
                                        size: 20,
                                        color: MohajonWarm.muted,
                                      ),
                                      hintText:
                                          l10n.t('emailHint'),
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return null;
                                      }
                                      if (!RegExp(
                                        r'^[^@]+@[^@]+\.[^@]+$',
                                      ).hasMatch(value.trim())) {
                                        return l10n.t('invalidEmail');
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  _FieldLabel(
                                    label: l10n.t('address'),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _addressCtrl,
                                    maxLines: 2,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    decoration:
                                        InputDecoration(
                                      prefixIcon: Padding(
                                        padding: EdgeInsets.only(
                                          bottom: 18,
                                        ),
                                        child: Icon(
                                          Icons
                                              .location_on_outlined,
                                          size: 20,
                                          color: MohajonWarm.muted,
                                        ),
                                      ),
                                      hintText:
                                          l10n.t('addressHint'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _SectionCard(
                                icon: Icons.notes_outlined,
                                iconColor: MohajonWarm.orange,
                                iconBackground: MohajonWarm.tintOrange,
                                title: l10n.t('notes'),
                                children: [
                                  TextFormField(
                                    controller: _notesCtrl,
                                    minLines: 3,
                                    maxLines: 5,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    decoration:
                                        InputDecoration(
                                      hintText:
                                          l10n.t('investorNotesHint'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      _SaveBar(
                        child: ActionButton(
                          onPressed: _save,
                          isBusy: isBusy,
                          icon: isEditing
                              ? Icons.save_rounded
                              : Icons.person_add_rounded,
                          label: isEditing
                              ? l10n.t('updateInvestor')
                              : l10n.t('saveInvestor'),
                          busyLabel: isEditing
                              ? l10n.t('updatingInvestor')
                              : l10n.t('savingInvestor'),
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
      label: l10n.t('savingInvestorSuffix'),
    );
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1200,
    );
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await runBusyAction(() async {
        final service = ref.read(investorServiceProvider);
        if (isEditing) {
          await service.update(
            id: widget.investor!.id,
            name: _nameCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            address: _addressCtrl.text.trim(),
            notes: _notesCtrl.text.trim(),
            photoUrl: widget.investor!.photoUrl,
            photoFile: _photo,
          );
        } else {
          await service.save(
            name: _nameCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            address: _addressCtrl.text.trim(),
            notes: _notesCtrl.text.trim(),
            photoFile: _photo,
          );
        }
      });
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(error))),
        );
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
            Icons.people_alt_rounded,
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

/// Circular photo picker matching the Add Client profile photo.
class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.photo,
    required this.photoUrl,
    required this.name,
    required this.onTap,
  });

  final File? photo;
  final String photoUrl;
  final String name;
  final VoidCallback? onTap;

  String get _initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    const size = 96.0;
    final l10n = AppLocalizations.of(context);
    ImageProvider? backgroundImage;
    if (photo != null) {
      backgroundImage = FileImage(photo!);
    } else if (photoUrl.isNotEmpty) {
      backgroundImage = NetworkImage(photoUrl);
    }

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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(size / 2),
                      child: backgroundImage != null
                          ? Image(
                              image: backgroundImage,
                              width: size,
                              height: size,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _default(),
                            )
                          : _default(),
                    ),
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
                        border: Border.all(
                          color: Colors.white,
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: MohajonWarm.primary.withValues(
                              alpha: 0.35,
                            ),
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
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: MohajonWarm.tintYellow,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: MohajonWarm.goldBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  photo != null || photoUrl.isNotEmpty
                      ? Icons.check_circle_rounded
                      : Icons.touch_app_rounded,
                  size: 13,
                  color: MohajonWarm.goldText,
                ),
                const SizedBox(width: 6),
                Text(
                  photo != null || photoUrl.isNotEmpty
                      ? l10n.t('photoAddedChange')
                      : l10n.t('tapToAddInvestorPhoto'),
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

  Widget _default() {
    return Center(
      child: _initials.isEmpty
          ? const Icon(
              Icons.person_rounded,
              size: 44,
              color: MohajonWarm.goldText,
            )
          : Text(
              _initials,
              style: const TextStyle(
                color: MohajonWarm.goldText,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
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
