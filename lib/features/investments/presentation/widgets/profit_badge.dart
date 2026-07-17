import 'package:flutter/material.dart';

class ProfitBadge extends StatelessWidget {
  const ProfitBadge({
    super.key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.fontSize = 12,
  });

  final double value;
  final String prefix;
  final String suffix;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final isPositive = value >= 0;
    final color = isPositive ? const Color(0xFF047857) : const Color(0xFFDC2626);
    final icon = isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: fontSize + 2, color: color),
        const SizedBox(width: 4),
        Text(
          '$prefix${value.toStringAsFixed(1)}$suffix',
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
