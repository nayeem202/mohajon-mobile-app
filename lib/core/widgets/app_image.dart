import 'dart:io';

import 'package:flutter/material.dart';

bool isRemoteImagePath(String path) =>
    path.startsWith('http://') || path.startsWith('https://');

ImageProvider<Object> imageProviderForPath(String path) =>
    isRemoteImagePath(path) ? NetworkImage(path) : FileImage(File(path));

class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorBuilder,
  });

  AppImage.file(
    File file, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorBuilder,
  }) : path = file.path;

  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) => Image(
        image: imageProviderForPath(path),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: errorBuilder,
      );
}
