import 'package:flutter/material.dart';

class ProfileTextField extends StatelessWidget {
  const ProfileTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.prefixIcon,
    this.keyboardType,
    this.maxLines = 1,
    this.textInputAction,
    this.onChanged,
    this.validator,
    this.focusNode,
    this.nextFocusNode,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final int maxLines;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final FocusNode? focusNode;
  final FocusNode? nextFocusNode;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          maxLines: maxLines,
          textInputAction: textInputAction ?? TextInputAction.next,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: nextFocusNode != null
              ? (_) => nextFocusNode!.requestFocus()
              : null,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon != null
                ? maxLines > 1
                      ? _TopAlignedPrefixIcon(icon: prefixIcon!, color: colors.onSurfaceVariant)
                      : Icon(prefixIcon, size: 20, color: colors.onSurfaceVariant)
                : null,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
}

class _TopAlignedPrefixIcon extends StatelessWidget {
  const _TopAlignedPrefixIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      heightFactor: 1.0,
      widthFactor: 1.0,
      alignment: Alignment.topCenter,
      child: Center(
        widthFactor: 1.0,
        heightFactor: 1.0,
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }
}
