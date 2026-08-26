import 'package:flutter/material.dart';

import '../../../../core/theme/mohajon_warm_theme.dart';

class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? MohajonWarm.primary : MohajonWarm.tintYellow,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: MohajonWarm.goldBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? MohajonWarm.ink : MohajonWarm.muted,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
