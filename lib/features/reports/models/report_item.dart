import 'package:flutter/material.dart';

class ReportItem {
  const ReportItem({
    required this.id,
    required this.icon,
    required this.title,
    required this.description,
    required this.startColor,
    required this.endColor,
    this.available = true,
  });

  final String id;
  final IconData icon;
  final String title;
  final String description;
  final Color startColor;
  final Color endColor;
  final bool available;
}
