import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_image.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    this.imagePath,
    this.size = 88,
    this.fontSize = 32,
    this.onTap,
  });

  final String name;
  final String? imagePath;
  final double size;
  final double fontSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          _buildAvatar(),
          if (onTap != null)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7A00),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    Widget avatar;
    if (imagePath != null) {
      avatar = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size / 2),
          child: AppImage.file(
            File(imagePath!),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, stk) => _defaultAvatar(),
          ),
        ),
      );
    } else {
      avatar = _defaultAvatar();
    }
    return avatar;
  }

  Widget _defaultAvatar() {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        image: DecorationImage(
          image: AssetImage(defaultAvatarAsset),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
