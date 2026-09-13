import 'package:flutter/material.dart';

import 'app_image.dart';

/// Default avatar placeholder shown while no profile picture is set,
/// used consistently across the whole app.
const String defaultAvatarAsset = 'assets/images/default_avatar.png';

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.imagePath,
    this.radius = 17,
    this.onTap,
    this.backgroundColor,
    this.textColor,
  });

  final String name;
  final String? imagePath;
  final double radius;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null && imagePath!.isNotEmpty;
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? const Color(0xFFD6F2EA),
      backgroundImage: hasImage
          ? imageProviderForPath(imagePath!)
          : const AssetImage(defaultAvatarAsset),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: avatar);
    }
    return avatar;
  }
}
