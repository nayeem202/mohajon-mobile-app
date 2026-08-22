import 'package:flutter/material.dart';

class AuthBrand {
  const AuthBrand._();

  static const backgroundColor = Color(0xFFFFF8E1);
  static const panelBackground = Colors.white;
  static const panelBorder = Color(0xFFF1DFAD);
  static const panelText = Color(0xFF2F3028);
  static const panelMuted = Color(0xFF77735F);
  static const primary = Color(0xFFFFC800);
  static const primaryDeep = Color(0xFFE98300);
  static const secondary = Color(0xFFD97706);
  static const secondarySoft = Color(0xFFFFF0A6);
  static const accent = Color(0xFFE98300);
  static const gold = Color(0xFFFFC800);
  static const shadow = Color(0xFF8C7538);
  static const danger = Color(0xFFD64545);
  static const buttonDisabled = Color(0xFFD7CFAE);
  static const onGold = Color(0xFF2F3028);

  static const gradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [primary, primaryDeep],
  );
  static const gradientTeal = gradient;

  static ThemeData theme(ThemeData base) {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: panelText,
      secondary: accent,
      onSecondary: Colors.white,
      error: danger,
      onError: Colors.white,
      surface: panelBackground,
      onSurface: panelText,
      surfaceContainerHighest: Color(0xFFFFFDF5),
      onSurfaceVariant: panelMuted,
      outline: panelBorder,
      outlineVariant: Color(0xFFF6EAC7),
      shadow: shadow,
      scrim: Colors.black,
      inverseSurface: panelText,
      onInverseSurface: Colors.white,
      inversePrimary: Color(0xFFB9C9FF),
    );
    return base.copyWith(
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: backgroundColor,
      textTheme: base.textTheme.apply(
        bodyColor: panelText,
        displayColor: panelText,
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        labelStyle: const TextStyle(
          color: panelMuted,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: const TextStyle(
          color: primary,
          fontWeight: FontWeight.w700,
        ),
        prefixIconColor: primary,
        suffixIconColor: panelMuted,
        hintStyle: const TextStyle(color: panelMuted, fontSize: 17),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: panelBorder, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: panelBorder, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: danger, width: 1.8),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        side: const BorderSide(color: panelBorder),
        fillColor: WidgetStateProperty.all(primary),
        checkColor: WidgetStateProperty.all(panelText),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
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
      dividerTheme: const DividerThemeData(color: panelBorder),
    );
  }
}
