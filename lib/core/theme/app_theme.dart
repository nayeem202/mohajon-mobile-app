import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFFD94801),
      onPrimary: Colors.white,
      secondary: Color(0xFF0F766E),
      onSecondary: Colors.white,
      tertiary: Color(0xFFB45309),
      onTertiary: Colors.white,
      error: Color(0xFFDC2626),
      onError: Colors.white,
      surface: Color(0xFFFFFEFC),
      onSurface: Color(0xFF2D2926),
      surfaceContainerHighest: Color(0xFFFCEFE3),
      onSurfaceVariant: Color(0xFF665F59),
      outline: Color(0xFFD8C4B0),
      outlineVariant: Color(0xFFEDE0D4),
      shadow: Color(0xFF46362B),
      scrim: Color(0xFF2D2926),
      inverseSurface: Color(0xFF292524),
      onInverseSurface: Colors.white,
      inversePrimary: Color(0xFFFFC089),
    );
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFFFF9F3),
      visualDensity: VisualDensity.standard,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFF2D2926),
        titleTextStyle: TextStyle(
          color: Color(0xFF2D2926),
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0xFF46362B).withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xFFD8C4B0)),
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD4C5B5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD4C5B5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: Colors.white,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE6D6C7),
        thickness: 1,
        space: 1,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: scheme.surfaceContainerHighest,
        selectedColor: scheme.primary.withValues(alpha: 0.14),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
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
        backgroundColor: const Color(0xFF3B3028),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
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
