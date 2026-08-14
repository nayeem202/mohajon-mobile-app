import 'package:flutter/material.dart';

class AuthBrand {
  const AuthBrand._();

  static const backgroundColor = Color(0xFFF5F8FF);
  static const panelBackground = Colors.white;
  static const panelBorder = Color(0xFFDDE5F5);
  static const panelText = Color(0xFF10234C);
  static const panelMuted = Color(0xFF657394);
  static const primary = Color(0xFF2057F5);
  static const primaryDeep = Color(0xFF1745D0);
  static const secondary = Color(0xFF2057F5);
  static const secondarySoft = Color(0xFFEAF0FF);
  static const accent = Color(0xFF7B4DF5);
  static const gold = Color(0xFFF6A623);
  static const shadow = Color(0xFF7187B5);
  static const danger = Color(0xFFD64545);
  static const buttonDisabled = Color(0xFFAAB6D1);
  static const onGold = Colors.white;

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
      onPrimary: Colors.white,
      secondary: accent,
      onSecondary: Colors.white,
      error: danger,
      onError: Colors.white,
      surface: panelBackground,
      onSurface: panelText,
      surfaceContainerHighest: Color(0xFFF1F5FF),
      onSurfaceVariant: panelMuted,
      outline: panelBorder,
      outlineVariant: Color(0xFFE9EEFA),
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
        checkColor: WidgetStateProperty.all(Colors.white),
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
