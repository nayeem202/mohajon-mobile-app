import 'package:flutter/material.dart';

import 'app_typography.dart';

class AppTheme {
  const AppTheme._();

  /// Primary family for a plain `Text` in [locale]. English text uses Roboto;
  /// Bangla text uses Kalpurush - see [AppType].
  static String fontFamilyFor(Locale? locale) => AppType.dataFamily(locale);

  static ThemeData light([Locale? locale]) {
    final fontFamily = fontFamilyFor(locale);
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF0B5BD0),
      onPrimary: Colors.white,
      secondary: Color(0xFF06B6D4),
      onSecondary: Colors.white,
      tertiary: Color(0xFF0E7490),
      onTertiary: Colors.white,
      error: Color(0xFFDC2626),
      onError: Colors.white,
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF0C2540),
      surfaceContainerHighest: Color(0xFFE9F2FB),
      onSurfaceVariant: Color(0xFF56708C),
      outline: Color(0xFFD5E3F2),
      outlineVariant: Color(0xFFE7EFF8),
      shadow: Color(0xFF062349),
      scrim: Color(0xFF0C2540),
      inverseSurface: Color(0xFF1F3B5C),
      onInverseSurface: Colors.white,
      inversePrimary: Color(0xFFA6D8FF),
    );
    final base = ThemeData(
      colorScheme: scheme,
      fontFamily: fontFamily,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF7FBFF),
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF0C2540),
        titleTextStyle: AppType.heading(
          const TextStyle(color: Color(0xFF0C2540), fontSize: 22),
          locale: locale,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0xFF062349).withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xFFD5E3F2)),
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppType.heading(
            const TextStyle(fontSize: 15),
            locale: locale,
            weight: AppType.buttonWeight,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: AppType.heading(
            const TextStyle(fontSize: 15),
            locale: locale,
            weight: AppType.buttonWeight,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: AppType.heading(
            const TextStyle(fontSize: 14),
            locale: locale,
            weight: AppType.buttonWeight,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          textStyle: AppType.heading(
            const TextStyle(fontSize: 16),
            locale: locale,
            weight: AppType.buttonWeight,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        // Labels and input text both sit in the data voice.
        labelStyle: AppType.body(
          const TextStyle(fontSize: 14),
          locale: locale,
          weight: FontWeight.w500,
        ),
        hintStyle: AppType.body(const TextStyle(fontSize: 14), locale: locale),
        prefixStyle: AppType.body(
          const TextStyle(fontSize: 14),
          locale: locale,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD5E3F2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD5E3F2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
    );
    return base.copyWith(
      textTheme: AppType.textTheme(
        base.textTheme.apply(
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
          fontFamily: fontFamily,
        ),
        locale,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: Colors.white,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppType.body(
            TextStyle(
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
              fontSize: 12,
            ),
            locale: locale,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE7EFF8),
        thickness: 1,
        space: 1,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: scheme.surfaceContainerHighest,
        selectedColor: scheme.primary.withValues(alpha: 0.14),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: AppType.body(
          TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w500),
          locale: locale,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: scheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
        dragHandleColor: scheme.outline,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF062349),
        contentTextStyle: AppType.body(
          const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          locale: locale,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primary.withValues(alpha: 0.14),
        circularTrackColor: scheme.primary.withValues(alpha: 0.14),
      ),
    );
  }
}
