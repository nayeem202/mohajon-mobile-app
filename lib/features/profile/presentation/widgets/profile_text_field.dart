import 'package:flutter/material.dart';

class ProfileTextField extends StatelessWidget {
  const ProfileTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
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
