import 'package:flutter/material.dart';

/// Shared design tokens extracted from the Home (dashboard) screen so every
/// main tab feels like one product.
class MohajonWarm {
  MohajonWarm._();

  static const primary = Color(0xFFFFC800);
  static const primarySoft = Color(0xFFFFD83D);
  static const primaryPale = Color(0xFFFFE36E);
  static const ink = Color(0xFF2F3028);
  static const muted = Color(0xFF77735F);
  static const goldBorder = Color(0xFFEADFAE);
  static const surface = Color(0xFFFFFCF0);
  static const card = Color(0xFFFFFDF7);
  static const tintYellow = Color(0xFFFFF4BF);
  static const tintGreen = Color(0xFFEFF7E5);
  static const tintOrange = Color(0xFFFFF0E2);
  static const tintRed = Color(0xFFFEF1F1);
  static const green = Color(0xFF047857);
  static const orange = Color(0xFFEA580C);
  static const red = Color(0xFFEF4444);
  static const goldText = Color(0xFF8A6500);

  /// Warm page background used by Home, Stock and Clients screens.
  static const pageGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.28, 0.47, 1.0],
    colors: [
      primary,
      primarySoft,
      Color(0xFFFFF0A6),
      surface,
    ],
  );

  static ThemeData theme(ThemeData base) {
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: primary,
        onPrimary: Colors.white,
        secondary: ink,
        onSecondary: Colors.white,
        tertiary: primarySoft,
        onTertiary: Colors.white,
        surface: surface,
        onSurface: ink,
        surfaceContainerHighest: Color(0xFFFFF0A6),
        onSurfaceVariant: muted,
        outline: goldBorder,
        outlineVariant: Color(0xFFFFF0A6),
      ),
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: base.appBarTheme.copyWith(
        foregroundColor: ink,
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        hintStyle: const TextStyle(
          color: muted,
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: goldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: goldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 1.6),
        ),
      ),
      floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
        backgroundColor: primary,
        foregroundColor: ink,
        elevation: 6,
        shape: const CircleBorder(),
      ),
      dividerTheme: base.dividerTheme.copyWith(
        color: const Color(0xFFF3ECDA),
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(
        textStyle: TextStyle(
          color: ink,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}
