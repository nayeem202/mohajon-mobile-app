import 'dart:io';

import 'package:flutter/material.dart';

import 'app_image.dart';

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

  String get _initials {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return parts.first[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? const Color(0xFFD6F2EA),
      backgroundImage: imagePath != null && imagePath!.isNotEmpty
          ? imageProviderForPath(imagePath!)
          : null,
      child: imagePath == null || imagePath!.isEmpty
          ? Text(
              _initials,
              style: TextStyle(
                color: textColor ?? const Color(0xFF0F766E),
                fontWeight: FontWeight.w900,
                fontSize: radius * 0.7,
              ),
            )
          : null,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: avatar);
    }
    return avatar;
  }
}
