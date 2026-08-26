import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_error.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/presentation/login_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../models/profile.dart';
import '../providers/profile_providers.dart';
import 'store_info_screen.dart';
import 'widgets/animated_section.dart';
import 'widgets/profile_avatar.dart';
import '../../../core/widgets/notification_bell.dart';

class ProfileOverviewScreen extends ConsumerStatefulWidget {
  const ProfileOverviewScreen({super.key});

  @override
  ConsumerState<ProfileOverviewScreen> createState() =>
      _ProfileOverviewScreenState();
}

class _ProfileOverviewScreenState
    extends ConsumerState<ProfileOverviewScreen> {
  final _picker = ImagePicker();
  String? _imagePath;
  String? _seedUserId;
  int _seedHash = -1;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);

    _seedProfile(profile);

    return Theme(
      data: MohajonWarm.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: MohajonWarm.pageGradient,
          ),
          child: SafeArea(
            child: Column(
              children: [
                _Header(onBack: () => Navigator.of(context).maybePop()),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      AnimatedSection(
                        child: _UserSection(
                          profile: profile,
                          imagePath: _imagePath,
                          onTapAvatar: _pickImage,
                        ),
                      ),
                      const SizedBox(height: 20),
                      AnimatedSection(
                        delay: const Duration(milliseconds: 80),
                        child: Container(
                          decoration: BoxDecoration(
                            color: MohajonWarm.card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: MohajonWarm.goldBorder),
                            boxShadow: [
                              BoxShadow(
                                color: MohajonWarm.ink.withValues(alpha: 0.06),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _MenuTile(
                                icon: Icons.store_rounded,
                                title: 'Store/Business Information',
                                subtitle: 'View and edit store details',
                                onTap: () => _openStoreInfo(profile),
                              ),
                              Divider(
                                  height: 1,
                                  indent: 16,
                                  endIndent: 16,
                                  color: MohajonWarm.goldBorder),
                              _MenuTile(
                                icon: Icons.settings_rounded,
                                title: 'Settings',
                                subtitle: 'App preferences & more',
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const SettingsScreen(),
                                  ),
                                ),
                              ),
                              Divider(
                                  height: 1,
                                  indent: 16,
                                  endIndent: 16,
                                  color: MohajonWarm.goldBorder),
                              _MenuTile(
                                icon: Icons.help_outline_rounded,
                                title: 'Help & Support',
                                subtitle: 'FAQs and contact',
                                onTap: () {},
                              ),
                              Divider(
                                  height: 1,
                                  indent: 16,
                                  endIndent: 16,
                                  color: MohajonWarm.goldBorder),
                              _MenuTile(
                                icon: Icons.logout_rounded,
                                title: 'Sign Out',
                                subtitle: 'Log out of your account',
                                iconColor: MohajonWarm.red,
                                titleColor: MohajonWarm.red,
                                onTap: _confirmLogout,
                              ),
                            ],
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
      ),
    );
  }

  void _seedProfile(Profile? profile) {
    if (profile == null) return;
    final hash = Object.hash(profile.ownerName, profile.imagePath);
    if (_seedUserId == profile.userId && _seedHash == hash) return;
    _imagePath = profile.imagePath;
    _seedUserId = profile.userId;
    _seedHash = hash;
  }

  Future<void> _pickImage() async {
    final remove = _imagePath != null;
    final result = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Profile Photo',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take a photo'),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
              if (remove) ...[
                const Divider(),
                ListTile(
                  leading: Icon(Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error),
                  title: Text(
                    'Remove photo',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _saveImagePath(null);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (result == null) return;

    try {
      final picked = await _picker.pickImage(
        source: result,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        _saveImagePath(picked.path);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not pick image')),
        );
      }
    }
  }

  Future<void> _saveImagePath(String? path) async {
    final current = ref.read(profileProvider);
    if (current == null) return;
    try {
      final updated = current.copyWith(imagePath: path);
      await ref.read(profileRepositoryProvider).saveProfile(updated);
      ref.read(profileVersionProvider.notifier).state++;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not upload profile image')),
        );
      }
    }
  }

  void _openStoreInfo(Profile? profile) {
    if (profile == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoreInfoScreen(profile: profile),
      ),
    );
  }

  void _confirmLogout() {
    final errorColor = Theme.of(context).colorScheme.error;
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Sign Out'),
          content: const Text(
            'Are you sure you want to sign out of your account?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _logout();
              },
              style: FilledButton.styleFrom(
                backgroundColor: errorColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    try {
      await ref.read(profileServiceProvider).logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(error))),
      );
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
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
              Icons.person_rounded,
              color: MohajonWarm.ink,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Profile',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: MohajonWarm.ink,
                  ),
                ),
                Text(
                  'Account & preferences',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF77735F),
                  ),
                ),
              ],
            ),
          ),
          const NotificationBell(),
        ],
      ),
    );
  }
}

class _UserSection extends StatelessWidget {
  const _UserSection({
    required this.profile,
    this.imagePath,
    this.onTapAvatar,
  });

  final Profile? profile;
  final String? imagePath;
  final VoidCallback? onTapAvatar;

  @override
  Widget build(BuildContext context) {
    final name = (profile?.ownerName ?? '').isNotEmpty
        ? profile!.ownerName
        : 'Store Owner';
    final store = profile?.storeName ?? '';
    final email = profile?.email ?? '';
    final phone = profile?.phone ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MohajonWarm.tintYellow, MohajonWarm.card],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MohajonWarm.goldBorder),
        boxShadow: [
          BoxShadow(
            color: MohajonWarm.primary.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          ProfileAvatar(
            name: name,
            imagePath: imagePath,
            size: 96,
            fontSize: 34,
            onTap: onTapAvatar,
          ),
          const SizedBox(height: 14),
          Text(
            name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: MohajonWarm.ink,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: MohajonWarm.goldText.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Store Owner',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: MohajonWarm.goldText,
              ),
            ),
          ),
          if (store.isNotEmpty || email.isNotEmpty || phone.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: MohajonWarm.goldBorder),
            const SizedBox(height: 12),
            if (store.isNotEmpty)
              _InfoRow(icon: Icons.store_rounded, text: store),
            if (email.isNotEmpty)
              _InfoRow(icon: Icons.email_rounded, text: email),
            if (phone.isNotEmpty)
              _InfoRow(icon: Icons.phone_rounded, text: phone),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: MohajonWarm.goldText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: MohajonWarm.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
    this.titleColor,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconColor;
  final Color? titleColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? MohajonWarm.primary;
    final effectiveTitleColor = titleColor ?? MohajonWarm.ink;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: effectiveIconColor.withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: effectiveIconColor.withValues(alpha: 0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: effectiveIconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: effectiveTitleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7C7660),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: MohajonWarm.goldText.withValues(alpha: 0.55),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
