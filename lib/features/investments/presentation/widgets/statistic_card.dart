import 'package:flutter/material.dart';

import '../../../../core/widgets/insight_widgets.dart';

class StatisticCard extends StatelessWidget {
  const StatisticCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return InsightMetricTile(
      label: label,
      value: value,
      icon: icon,
      accent: color,
      caption: subtitle,
    );
  }
}
