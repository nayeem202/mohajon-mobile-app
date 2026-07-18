import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profile/presentation/profile_overview_screen.dart';
import '../../features/profile/providers/profile_providers.dart';
import '../../features/settings/providers/shop_profile_providers.dart';
import 'app_avatar.dart';

class ShopAvatar extends ConsumerWidget {
  const ShopAvatar({
    super.key,
    this.radius = 17,
    this.onTap,
    this.backgroundColor,
    this.textColor,
  });

  final double radius;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopName = ref.watch(shopProfileProvider).value?.shopName ?? '';
    final imagePath = ref.watch(profileProvider)?.imagePath;

    return AppAvatar(
      name: shopName,
      imagePath: imagePath,
      radius: radius,
      onTap: onTap ?? () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProfileOverviewScreen()),
      ),
      backgroundColor: backgroundColor,
      textColor: textColor,
    );
  }
}
