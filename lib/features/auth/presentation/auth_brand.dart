import 'package:flutter/material.dart';

class AuthBrand {
  const AuthBrand._();

  static const backgroundColor = Color(0xFFFFF8F1);

  static const panelBackground = Color(0xFFFFFFFF);
  static const panelBorder = Color(0xFFE9E1D8);
  static const panelText = Color(0xFF17201B);
  static const panelMuted = Color(0xFF667085);
  static const primary = Color(0xFFE98300);
  static const primaryDeep = Color(0xFFF97316);
  static const secondary = Color(0xFFEA580C);
  static const secondarySoft = Color(0xFFFCE7C8);
  static const accent = Color(0xFFFDF1E3);
  static const shadow = Color(0xFF0B1F17);
  static const danger = Color(0xFFDC2626);
  static const buttonDisabled = Color(0xFFF3D7A6);

  static ThemeData theme(ThemeData base) {
    return base.copyWith(
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: panelBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: panelBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: panelBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        side: const BorderSide(color: panelBorder),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return panelBackground;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: panelText,
          side: const BorderSide(color: panelBorder),
        ),
      ),
      iconTheme: base.iconTheme.copyWith(color: panelMuted),
      progressIndicatorTheme: base.progressIndicatorTheme.copyWith(
        color: primary,
      ),
    );
  }
}
