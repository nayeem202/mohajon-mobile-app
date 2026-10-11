import 'package:flutter/material.dart';

import 'app_typography.dart';

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
    colors: [primary, primarySoft, Color(0xFFFFF0A6), surface],
  );

  static ThemeData theme(ThemeData base, {Locale? locale}) {
    // A user can choose Bangla inside the app while Android remains in
    // English. Preserve that app choice instead of reading the device locale.
    final effectiveLocale = locale ?? _localeFromRootTheme(base);
    return base.copyWith(
      textTheme: AppType.textTheme(
        base.textTheme.copyWith(
          bodyLarge: base.textTheme.bodyLarge?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: ink,
          ),
        ),
        effectiveLocale,
      ),
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
      cardTheme: base.cardTheme.copyWith(
        elevation: 0,
        color: card,
        margin: EdgeInsets.zero,
        shadowColor: ink.withValues(alpha: 0.07),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: goldBorder),
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: primary,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        hintStyle: AppType.body(
          const TextStyle(
            color: muted,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
          locale: effectiveLocale,
        ),
        labelStyle: AppType.body(
          const TextStyle(
            color: muted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          locale: effectiveLocale,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: red, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: red, width: 1.6),
        ),
        errorStyle: AppType.body(
          const TextStyle(
            color: red,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          locale: effectiveLocale,
        ),
      ),
      floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
        backgroundColor: primary,
        foregroundColor: ink,
        elevation: 6,
        shape: const CircleBorder(),
      ),
      dividerTheme: base.dividerTheme.copyWith(color: const Color(0xFFF3ECDA)),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: AppType.body(
          const TextStyle(
            color: ink,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
          locale: effectiveLocale,
        ),
        contentTextStyle: AppType.body(
          const TextStyle(color: muted, fontSize: 13, height: 1.45),
          locale: effectiveLocale,
        ),
      ),
      bottomSheetTheme: base.bottomSheetTheme.copyWith(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: AppType.body(
          const TextStyle(
            color: ink,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          locale: effectiveLocale,
        ),
      ),
    );
  }

  static Locale? _localeFromRootTheme(ThemeData base) {
    final families = [
      base.textTheme.bodyLarge?.fontFamily,
      base.textTheme.titleLarge?.fontFamily,
      base.textTheme.labelLarge?.fontFamily,
    ];
    return families.contains(AppType.bengali) ? const Locale('bn') : null;
  }
}
