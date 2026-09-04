import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/app_config.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/app_error.dart';
import '../../../core/widgets/action_button.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';
import '../models/staff_model.dart';
import '../models/staff_role.dart';
import '../providers/staff_providers.dart';
import '../services/staff_api_service.dart';

/// Full-screen staff creation/editing form. Roles and menu access lists are
/// fetched from the Java service (configurable from the DB), and the shop
/// owner picks the role plus which menus the staff member can access.
class StaffFormScreen extends ConsumerStatefulWidget {
  const StaffFormScreen({super.key, this.staff});

  final StaffMember? staff;

  @override
  ConsumerState<StaffFormScreen> createState() => _StaffFormScreenState();
}

class _StaffFormScreenState extends ConsumerState<StaffFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _picker = ImagePicker();

  String? _imagePath;
  String? _photoUrl;
  String _selectedRole = '';
  final Set<String> _selectedMenus = {};
  bool _saving = false;

  bool get _isEditing => widget.staff != null;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    final s = widget.staff;
    if (s != null) {
      _nameCtrl.text = s.name;
      _phoneCtrl.text = s.phone;
      _emailCtrl.text = s.email;
      _selectedRole = s.role;
      _selectedMenus.addAll(s.menuCodes);
      _photoUrl = s.photoUrl;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String get _initials {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return widget.staff?.initials ?? '?';
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final value = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return value.length == 1 ? '${value}N' : value;
  }

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? MohajonWarm.red : null,
        duration: const Duration(seconds: 2),
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
              Text(
                _l10n.t('staffPhoto'),
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
                  _l10n.t('takeAPhoto'),
                  style: const TextStyle(
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
                title: Text(
                  _l10n.t('chooseFromGallery'),
                  style: const TextStyle(
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
      if (mounted) _showToast(_l10n.t('couldNotPickImage'), isError: true);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRole.isEmpty) {
      _showToast(_l10n.t('pleaseSelectRole'), isError: true);
      return;
    }
    if (_selectedMenus.isEmpty) {
      _showToast(_l10n.t('selectAtLeastMenu'), isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final api = ref.read(staffApiServiceProvider);
      String? photoUrl = _photoUrl;
      if (_imagePath != null) {
        photoUrl = await api.uploadImage(File(_imagePath!));
      }
      if (_isEditing) {
        await api.updateStaff(
          userId: widget.staff!.id,
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          role: _selectedRole,
          menuCodes: _selectedMenus.toList(),
          photoUrl: photoUrl,
        );
      } else {
        await api.createStaff(
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          role: _selectedRole,
          menuCodes: _selectedMenus.toList(),
          photoUrl: photoUrl,
        );
      }
      ref.invalidate(staffListProvider);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      debugPrint('APP_ERROR >>> ${error.runtimeType}: $error');
      _showToast(
        error is StaffApiException
            ? error.message
            : friendlyErrorMessage(error,
                fallback: _l10n.t('couldNotSaveStaff')),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rolesAsync = ref.watch(staffRolesProvider);
    final menusAsync = ref.watch(staffMenusProvider);

    final roles = rolesAsync.value ?? const <StaffRole>[];
    final menus = menusAsync.value ?? const <AppMenu>[];
    if (_selectedRole.isEmpty && roles.isNotEmpty) {
      _selectedRole = roles.first.code;
    }
    final loading = rolesAsync.isLoading || menusAsync.isLoading;
    final error = rolesAsync.hasError || menusAsync.hasError;

    return Theme(
      data: MohajonWarm.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: MohajonWarm.pageGradient),
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
                child: loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: MohajonWarm.primary,
                        ),
                      )
                    : error
                        ? _errorState()
                        : Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                Expanded(
                                  child: ListView(
                                    padding: const EdgeInsets.fromLTRB(
                                        18, 12, 18, 16),
                                    children: [
                                      _FormHeader(
                                        title: _isEditing
                                            ? l10n.t('editStaffMember')
                                            : l10n.t('addStaffMember'),
                                        subtitle: l10n.t('teamAndPermissions'),
                                        onBack: () =>
                                            Navigator.of(context).maybePop(),
                                      ),
                                      const SizedBox(height: 18),
                                      _StaffPhotoPicker(
                                        initials: _initials,
                                        imagePath: _imagePath,
                                        photoUrl: _photoUrl,
                                        onTap: _saving ? null : _pickImage,
                                      ),
                                      const SizedBox(height: 18),
                                      _SectionCard(
                                        icon: Icons.badge_outlined,
                                        iconColor: MohajonWarm.goldText,
                                        iconBackground: MohajonWarm.tintYellow,
                                        title: l10n.t('staffDetails'),
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
                                            decoration: const InputDecoration(
                                              prefixIcon: Icon(
                                                Icons.person_outline_rounded,
                                                size: 20,
                                                color: MohajonWarm.muted,
                                              ),
                                              hintText: 'e.g. Karim Uddin',
                                            ),
                                            validator: (v) =>
                                                v?.trim().isEmpty == true
                                                    ? l10n.t('nameIsRequired')
                                                    : null,
                                          ),
                                          const SizedBox(height: 14),
                                          _FieldLabel(
                                              label: l10n.t('phoneNumber')),
                                          const SizedBox(height: 8),
                                          TextFormField(
                                            controller: _phoneCtrl,
                                            keyboardType: TextInputType.phone,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                              LengthLimitingTextInputFormatter(
                                                  13),
                                            ],
                                            decoration: const InputDecoration(
                                              prefixIcon: Icon(
                                                Icons.phone_outlined,
                                                size: 20,
                                                color: MohajonWarm.muted,
                                              ),
                                              hintText: 'e.g. 01712-345678',
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      _SectionCard(
                                        icon: Icons.lock_outline_rounded,
                                        iconColor: MohajonWarm.green,
                                        iconBackground: MohajonWarm.tintGreen,
                                        title: l10n.t('signInCredentials'),
                                        children: [
                                          _FieldLabel(
                                            label: l10n.t('email'),
                                            required: true,
                                          ),
                                          const SizedBox(height: 8),
                                          TextFormField(
                                            controller: _emailCtrl,
                                            keyboardType:
                                                TextInputType.emailAddress,
                                            enabled: !_isEditing,
                                            autocorrect: false,
                                            decoration: const InputDecoration(
                                              prefixIcon: Icon(
                                                Icons.email_outlined,
                                                size: 20,
                                                color: MohajonWarm.muted,
                                              ),
                                              hintText:
                                                  'e.g. karim@hishabbondhu.com',
                                            ),
                                            validator: (v) {
                                              final trimmed = v?.trim() ?? '';
                                              if (!_isEditing &&
                                                  trimmed.isEmpty) {
                                                return l10n.t(
                                                    'emailIsRequiredSignIn');
                                              }
                                              if (trimmed.isNotEmpty) {
                                                final emailRegex = RegExp(
                                                    r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                                                if (!emailRegex
                                                    .hasMatch(trimmed)) {
                                                  return l10n.t(
                                                      'validEmailAddress');
                                                }
                                              }
                                              return null;
                                            },
                                          ),
                                          if (!_isEditing) ...[
                                            const SizedBox(height: 14),
                                            _FieldLabel(
                                              label: l10n.t('password'),
                                              required: true,
                                            ),
                                            const SizedBox(height: 8),
                                            TextFormField(
                                              controller: _passwordCtrl,
                                              obscureText: true,
                                              decoration:
                                                  InputDecoration(
                                                prefixIcon: Icon(
                                                  Icons.password_rounded,
                                                  size: 20,
                                                  color: MohajonWarm.muted,
                                                ),
                                                hintText:
                                                    l10n.t('minPassword'),
                                              ),
                                              validator: (v) {
                                                if (v?.trim().isEmpty == true) {
                                                  return l10n.t(
                                                      'passwordIsRequired');
                                                }
                                                if ((v?.length ?? 0) < 6) {
                                                  return l10n.t(
                                                      'passwordTooShort');
                                                }
                                                return null;
                                              },
                                            ),
                                          ],
                                          if (_isEditing) ...[
                                            const SizedBox(height: 12),
                                            Text(
                                              l10n.t('emailPasswordUnchanged'),
                                              style: const TextStyle(
                                                color: MohajonWarm.muted,
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      _SectionCard(
                                        icon:
                                            Icons.admin_panel_settings_rounded,
                                        iconColor: MohajonWarm.orange,
                                        iconBackground: MohajonWarm.tintOrange,
                                        title: l10n.t('role'),
                                        children: [
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: roles.map((role) {
                                              final isSelected =
                                                  role.code == _selectedRole;
                                              return _PillChip(
                                                label: role.name,
                                                selected: isSelected,
                                                onTap: () => setState(() =>
                                                    _selectedRole = role.code),
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      _menuSection(menus),
                                    ],
                                  ),
                                ),
                                _SaveBar(
                                  child: ActionButton(
                                    onPressed: _saving ? null : _submit,
                                    isBusy: _saving,
                                    icon: _isEditing
                                        ? Icons.save_rounded
                                        : Icons.person_add_rounded,
                                    label: _isEditing
                                        ? l10n.t('saveChanges')
                                        : l10n.t('createStaffMember'),
                                    busyLabel: _isEditing
                                        ? l10n.t('updating')
                                        : l10n.t('creating'),
                                  ),
                                ),
                              ],
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: MohajonWarm.goldBorder),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 28,
                color: MohajonWarm.goldText,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _l10n.t('couldNotLoadRolesMenus'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: MohajonWarm.ink,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                ref.invalidate(staffRolesProvider);
                ref.invalidate(staffMenusProvider);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: MohajonWarm.ink,
                side: const BorderSide(color: MohajonWarm.goldBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(_l10n.t('retry')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuSection(List<AppMenu> menus) {
    final sections = <String, List<AppMenu>>{};
    for (final menu in menus) {
      sections.putIfAbsent(menu.section, () => []).add(menu);
    }
    return _SectionCard(
      icon: Icons.apps_rounded,
      iconColor: MohajonWarm.red,
      iconBackground: MohajonWarm.tintRed,
      title: _l10n.t('menuAccess'),
      children: [
        Text(
          _l10n.t('menuAccessHelp'),
          style: const TextStyle(
            color: MohajonWarm.muted,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        for (final entry in sections.entries)
          _MenuTypeSection(
            key: ValueKey(entry.key),
            label: _sectionLabel(entry.key),
            menus: entry.value,
            selectedCodes: _selectedMenus,
            onMenuChanged: (code, checked) {
              setState(() {
                if (checked) {
                  _selectedMenus.add(code);
                } else {
                  _selectedMenus.remove(code);
                }
              });
            },
            onToggleAll: (selectAll) {
              setState(() {
                for (final menu in entry.value) {
                  if (selectAll) {
                    _selectedMenus.add(menu.code);
                  } else {
                    _selectedMenus.remove(menu.code);
                  }
                }
              });
            },
          ),
      ],
    );
  }

  String _sectionLabel(String section) {
    return switch (section) {
      'MAIN' => _l10n.t('sectionMainMenu'),
      'OPERATIONS' => _l10n.t('sectionOperations'),
      'FINANCE' => _l10n.t('sectionFinance'),
      'APP' => _l10n.t('sectionApp'),
      _ => section,
    };
  }
}

/// Round photo picker matching the Add Client profile photo.
class _StaffPhotoPicker extends StatelessWidget {
  const _StaffPhotoPicker({
    required this.initials,
    required this.imagePath,
    required this.photoUrl,
    required this.onTap,
  });

  final String initials;
  final String? imagePath;
  final String? photoUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const size = 96.0;
    final l10n = AppLocalizations.of(context);
    final hasPhoto = imagePath != null || (photoUrl?.isNotEmpty == true);

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
                    child: ClipOval(
                      child: imagePath != null
                          ? Image.file(
                              File(imagePath!),
                              width: size,
                              height: size,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _fallback(),
                            )
                          : (photoUrl?.isNotEmpty == true)
                              ? Image.network(
                                  '${AppConfig.apiBaseUrl}$photoUrl',
                                  width: size,
                                  height: size,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => _fallback(),
                                )
                              : _fallback(),
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
                        border: Border.all(color: Colors.white, width: 2.5),
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
                  hasPhoto
                      ? Icons.check_circle_rounded
                      : Icons.touch_app_rounded,
                  size: 13,
                  color: MohajonWarm.goldText,
                ),
                const SizedBox(width: 6),
                Text(
                  hasPhoto
                      ? l10n.t('photoAddedChange')
                      : l10n.t('tapToAddStaffPhoto'),
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

  Widget _fallback() {
    return Center(
      child: Text(
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
            Icons.group_rounded,
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

/// Collapsible menu group. Shows a type-level select-all checkbox (tri-state)
/// and, when expanded, the individual menu checkboxes for that section.
class _MenuTypeSection extends StatefulWidget {
  const _MenuTypeSection({
    super.key,
    required this.label,
    required this.menus,
    required this.selectedCodes,
    required this.onMenuChanged,
    required this.onToggleAll,
  });

  final String label;
  final List<AppMenu> menus;
  final Set<String> selectedCodes;
  final void Function(String code, bool checked) onMenuChanged;
  final void Function(bool selectAll) onToggleAll;

  @override
  State<_MenuTypeSection> createState() => _MenuTypeSectionState();
}

class _MenuTypeSectionState extends State<_MenuTypeSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final allSelected =
        widget.menus.every((m) => widget.selectedCodes.contains(m.code));
    final anySelected =
        widget.menus.any((m) => widget.selectedCodes.contains(m.code));
    final triValue = allSelected ? true : (anySelected ? null : false);
    final selectedCount =
        widget.menus.where((m) => widget.selectedCodes.contains(m.code)).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MohajonWarm.goldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.label,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: MohajonWarm.ink,
                            ),
                          ),
                        ),
                        if (selectedCount > 0)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: MohajonWarm.tintYellow,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: MohajonWarm.primary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              '$selectedCount/${widget.menus.length}',
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: MohajonWarm.goldText,
                              ),
                            ),
                          ),
                        const SizedBox(width: 4),
                        Icon(
                          _expanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 20,
                          color: MohajonWarm.muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Checkbox(
                tristate: true,
                value: triValue,
                activeColor: MohajonWarm.primary,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (_) => widget.onToggleAll(!allSelected),
              ),
              const SizedBox(width: 6),
            ],
          ),
          if (_expanded)
            Column(
              children: [
                const Divider(height: 1, color: Color(0xFFF3ECDA)),
                for (var i = 0; i < widget.menus.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: Color(0xFFF3ECDA),
                    ),
                  _MenuCheckboxTile(
                    menu: widget.menus[i],
                    checked: widget.selectedCodes.contains(widget.menus[i].code),
                    onChanged: (checked) =>
                        widget.onMenuChanged(widget.menus[i].code, checked),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

String _menuLocalizedName(String code, AppLocalizations l10n) {
  return switch (code) {
    'HOME' => l10n.t('home'),
    'SALES' => l10n.t('sales'),
    'STOCK' => l10n.t('stock'),
    'CLIENTS' => l10n.t('clients'),
    'PRODUCTS' => l10n.t('products'),
    'ADD_PRODUCT' => l10n.t('addProductItem'),
    'ADD_CUSTOMER' => l10n.t('addCustomer'),
    'VENDORS' => l10n.t('vendors'),
    'EXPENSES' => l10n.t('expenses'),
    'INVESTORS' => l10n.t('investors'),
    'BARCODE' => l10n.t('barcodeScan'),
    'PURCHASE' => l10n.t('purchase'),
    'DUE' => l10n.t('due'),
    'INVESTMENTS' => l10n.t('investments'),
    'REPORTS' => l10n.t('reports'),
    'SALES_HISTORY' => l10n.t('salesHistory'),
    'PROFILE' => l10n.t('myProfile'),
    'STAFF' => l10n.t('staff'),
    'SETTINGS' => l10n.t('settings'),
    'SECURITY' => l10n.t('accountSecurity'),
    'PRIVACY' => l10n.t('privacy'),
    _ => code,
  };
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

class _MenuCheckboxTile extends StatelessWidget {
  const _MenuCheckboxTile({
    required this.menu,
    required this.checked,
    required this.onChanged,
  });

  final AppMenu menu;
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InkWell(
      onTap: () => onChanged(!checked),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              checked
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 22,
              color: checked
                  ? MohajonWarm.primary
                  : MohajonWarm.goldBorder,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _menuLocalizedName(menu.code, l10n),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: MohajonWarm.ink,
                ),
              ),
            ),
          ],
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
