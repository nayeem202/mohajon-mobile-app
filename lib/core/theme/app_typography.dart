import 'package:flutter/material.dart';

/// The app speaks in two typographic voices, and [AppType] is the single place
/// that decides which one applies where.
///
/// | Voice | Family | Used for |
/// |---|---|---|
/// | Brand + Data | Roboto | all English UI text |
///
/// Both families are Latin-only, so every style carries a Bangla fallback.
/// That matters because the English UI still shows Bangla strings in a few
/// places - a Bangla shop name, a Bangla product name in a table. Without the
/// fallback those render as empty tofu boxes.
///
/// The Bangla locale is intentionally left on Kalpurush, which is what the app
/// has always used for Bangla and what the brand is tuned around.
class AppType {
  const AppType._();

  /// Shared English typeface, matching the Roboto lettering in the reference.
  static const brand = 'Roboto';

  /// Keep headings, controls and data in one consistent English typeface.
  static const data = 'Roboto';

  /// Bangla display font, unchanged from before.
  static const bengali = 'Kalpurush';

  /// Bangla UI font, used as the secondary fallback for long Bangla body copy.
  static const bengaliUi = 'NotoSansBengali';

  static const _fallback = [bengali, bengaliUi, 'Roboto'];

  /// Heading weight. Medium/SemiBold keeps headings clear without crowding.
  static const brandWeight = FontWeight.w600;

  /// Button weight sits between Medium and SemiBold so long labels such as
  /// "Send verification email" stay comfortable.
  static const buttonWeight = FontWeight.w600;

  static bool isBengali(Locale? locale) => locale?.languageCode == 'bn';

  /// Family for a heading in [locale].
  static String brandFamily(Locale? locale) =>
      isBengali(locale) ? bengali : brand;

  /// Family for body copy, labels, inputs, tables and numbers in [locale].
  static String dataFamily(Locale? locale) =>
      isBengali(locale) ? bengali : data;

  static List<String> fallback(Locale? locale) => _fallback;

  /// Rebases [base] onto the shared English typeface. Weights are only applied
  /// where the base did not already pick something deliberate, preserving the
  /// existing visual hierarchy.
  static TextTheme textTheme(TextTheme base, Locale? locale) {
    if (isBengali(locale)) return base;

    TextStyle asBrand(TextStyle? style) => (style ?? const TextStyle())
        .copyWith(fontFamily: brand, fontFamilyFallback: _fallback);

    TextStyle asData(TextStyle? style) => (style ?? const TextStyle()).copyWith(
      fontFamily: data,
      fontFamilyFallback: _fallback,
    );

    return base.copyWith(
      displayLarge: asBrand(base.displayLarge),
      displayMedium: asBrand(base.displayMedium),
      displaySmall: asBrand(base.displaySmall),
      headlineLarge: asBrand(base.headlineLarge),
      headlineMedium: asBrand(base.headlineMedium),
      headlineSmall: asBrand(base.headlineSmall),
      titleLarge: asBrand(base.titleLarge),
      titleMedium: asBrand(base.titleMedium),
      titleSmall: asBrand(base.titleSmall),
      bodyLarge: asData(base.bodyLarge),
      bodyMedium: asData(base.bodyMedium),
      bodySmall: asData(base.bodySmall),
      labelLarge: asData(base.labelLarge),
      labelMedium: asData(base.labelMedium),
      labelSmall: asData(base.labelSmall),
    );
  }

  /// Text style for a heading that must read as brand voice regardless of what
  /// the surrounding slot inherited. Used by shared widgets so a screen's own
  /// overrides cannot silently pull a heading back into the data voice.
  ///
  /// Pass [locale] so Bangla keeps Kalpurush; omit it in widgets that already
  /// resolved the locale from context.
  static TextStyle heading(
    TextStyle? base, {
    Locale? locale,
    double? fontSize,
    Color? color,
    FontWeight? weight,
    double? letterSpacing,
    double? height,
  }) {
    return (base ?? const TextStyle()).copyWith(
      fontFamily: brandFamily(locale),
      fontFamilyFallback: _fallback,
      fontSize: fontSize,
      color: color,
      fontWeight: weight ?? brandWeight,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Text style for body copy, labels, inputs, tables and numbers. No default
  /// weight, so the caller's choice is preserved.
  static TextStyle body(
    TextStyle? base, {
    Locale? locale,
    double? fontSize,
    Color? color,
    FontWeight? weight,
    double? letterSpacing,
    double? height,
  }) {
    return (base ?? const TextStyle()).copyWith(
      fontFamily: dataFamily(locale),
      fontFamilyFallback: _fallback,
      fontSize: fontSize,
      color: color,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      height: height,
    );
  }
}
