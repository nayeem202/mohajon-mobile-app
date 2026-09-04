import 'package:flutter/material.dart';

class TourStep {
  const TourStep({
    required this.targetKey,
    required this.title,
    required this.description,
    required this.tabIndex,
  });

  final GlobalKey targetKey;
  final String title;
  final String description;
  final int tabIndex;
}
