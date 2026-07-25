import 'package:flutter/material.dart';

class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.busyLabel,
    this.icon,
    this.isBusy = false,
    this.isDestructive = false,
    this.expanded = true,
    this.height = 52,
  });

  final VoidCallback? onPressed;
  final String label;
  final String? busyLabel;
  final IconData? icon;
  final bool isBusy;
  final bool isDestructive;
  final bool expanded;
  final double height;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton.icon(
      onPressed: isBusy ? null : onPressed,
      icon: isBusy
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: isDestructive ? Colors.white : Colors.white,
              ),
            )
          : icon != null
              ? Icon(icon, size: 20)
              : const SizedBox.shrink(),
      label: Text(
        isBusy ? (busyLabel ?? 'Saving...') : label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: isDestructive
            ? Theme.of(context).colorScheme.error
            : const Color(0xFFF97316),
        foregroundColor: Colors.white,
        minimumSize: Size(expanded ? double.infinity : 0, height),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );

    if (expanded) {
      return SizedBox(
        height: height,
        child: button,
      );
    }
    return button;
  }
}
