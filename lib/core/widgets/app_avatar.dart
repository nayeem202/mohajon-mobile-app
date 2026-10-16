import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'app_image.dart';

/// Default avatar placeholder shown while no profile picture is set,
/// used consistently across the whole app.
const String defaultAvatarAsset = 'assets/images/default_avatar.svg';

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
    final avatar = ClipOval(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: hasImage
            ? Image(
                image: imageProviderForPath(imagePath!),
                fit: BoxFit.cover,
                // Any load error (missing local file, dead remote URL)
                // falls back to the default avatar instead of a blank circle.
                errorBuilder: (context, error, stackTrace) =>
                    _defaultAvatar(backgroundColor),
              )
            : _defaultAvatar(backgroundColor),
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: avatar);
    }
    return avatar;
  }

  Widget _defaultAvatar(Color? backgroundColor) {
    return ColoredBox(
      color: backgroundColor ?? const Color(0xFFFFF3CE),
      child: SvgPicture.asset(
        defaultAvatarAsset,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }
}
