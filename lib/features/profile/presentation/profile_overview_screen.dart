import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/app/app_providers.dart';
import '../../auth/presentation/login_screen.dart';
import '../models/profile.dart';
import '../providers/profile_providers.dart';
import 'store_info_screen.dart';
import 'widgets/animated_section.dart';
import 'widgets/profile_avatar.dart';

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
    final colors = Theme.of(context).colorScheme;

    _seedProfile(profile);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          AnimatedSection(
            child: _UserSection(
              profile: profile,
              imagePath: _imagePath,
              onTapAvatar: _pickImage,
            ),
          ),
          const SizedBox(height: 24),
          AnimatedSection(
            delay: const Duration(milliseconds: 80),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colors.outlineVariant),
              ),
              child: Column(
                children: [
                  _MenuTile(
                    icon: Icons.store_rounded,
                    title: 'Store/Business Information',
                    subtitle: 'View and edit store details',
                    onTap: () => _openStoreInfo(profile),
                  ),
                  Divider(height: 1, indent: 16, endIndent: 16, color: colors.outlineVariant),
                  _MenuTile(
                    icon: Icons.settings_rounded,
                    title: 'Settings',
                    subtitle: 'App preferences & more',
                    onTap: () {},
                  ),
                  Divider(height: 1, indent: 16, endIndent: 16, color: colors.outlineVariant),
                  _MenuTile(
                    icon: Icons.help_outline_rounded,
                    title: 'Help & Support',
                    subtitle: 'FAQs and contact',
                    onTap: () {},
                  ),
                  Divider(height: 1, indent: 16, endIndent: 16, color: colors.outlineVariant),
                  _MenuTile(
                    icon: Icons.logout_rounded,
                    title: 'Sign Out',
                    subtitle: 'Log out of your account',
                    iconColor: colors.error,
                    titleColor: colors.error,
                    onTap: _confirmLogout,
                  ),
                ],
              ),
            ),
          ),
        ],
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
    final updated = current.copyWith(imagePath: path);
    await ref.read(profileRepositoryProvider).saveProfile(updated);
    ref.read(profileVersionProvider.notifier).state++;
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
                backgroundColor: Theme.of(context).colorScheme.error,
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
        SnackBar(content: Text(error.toString())),
      );
    }
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
    final colors = Theme.of(context).colorScheme;
    final name = (profile?.ownerName ?? '').isNotEmpty
        ? profile!.ownerName
        : 'Store Owner';

    return Column(
      children: [
        ProfileAvatar(
          name: name,
          imagePath: imagePath,
          size: 88,
          fontSize: 32,
          onTap: onTapAvatar,
        ),
        const SizedBox(height: 14),
        Text(
          name,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Store Owner',
          style: TextStyle(
            fontSize: 14,
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Joined June 2025',
          style: TextStyle(
            fontSize: 12,
            color: colors.onSurfaceVariant.withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
    final colors = Theme.of(context).colorScheme;
    final effectiveIconColor = iconColor ?? colors.primary;
    final effectiveTitleColor = titleColor ?? colors.onSurface;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: effectiveIconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
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
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: colors.onSurfaceVariant.withValues(alpha: 0.5),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
