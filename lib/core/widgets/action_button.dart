import 'package:flutter/material.dart';

import '../services/app_feedback.dart';

class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.onPressed,
    required this.isBusy,
    this.icon,
    required this.label,
    required this.busyLabel,
    this.expanded = true,
    this.height = 48,
  });

  final VoidCallback? onPressed;
  final bool isBusy;
  final IconData? icon;
  final String label;
  final String busyLabel;
  final bool expanded;
  final double height;

  @override
  Widget build(BuildContext context) {
    final child = isBusy
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Text(busyLabel),
            ],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Text(label),
            ],
          );

    final style = FilledButton.styleFrom(
      minimumSize: Size(expanded ? double.infinity : 0, height),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
    );

    return FilledButton(
      onPressed: isBusy
          ? null
          : () {
              AppFeedback.tap();
              onPressed?.call();
            },
      style: style,
      child: child,
    );
  }
}