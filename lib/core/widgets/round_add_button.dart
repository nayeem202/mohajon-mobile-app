import 'package:flutter/material.dart';

class RoundAddButton extends StatelessWidget {
  const RoundAddButton({
    super.key,
    required this.onPressed,
    this.size = 44,
    this.backgroundColor = const Color(0xFFF97316),
  });

  final VoidCallback? onPressed;
  final double size;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(size / 2),
        elevation: 0,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(size / 2),
          child: Center(
            child: Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: size * 0.55,
            ),
          ),
        ),
      ),
    );
  }
}
