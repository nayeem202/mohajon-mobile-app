import 'package:flutter/material.dart';

class AppIconAsset extends StatelessWidget {
  const AppIconAsset({
    super.key,
    required this.assetPath,
    this.size = 24,
    this.color,
  });

  final IconData assetPath;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Icon(assetPath, size: size, color: color);
  }
}