import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inventory_1/core/theme/app_typography.dart';
import 'package:inventory_1/core/theme/app_theme.dart';

void main() {
  testWidgets('English theme routes headings to Poppins and body to Inter', (
    tester,
  ) async {
    final theme = AppTheme.light(const Locale('en'));
    final t = theme.textTheme;

    // Heading slots.
    expect(t.displayLarge?.fontFamily, AppType.brand);
    expect(t.headlineMedium?.fontFamily, AppType.brand);
    expect(t.titleLarge?.fontFamily, AppType.brand);
    expect(t.titleSmall?.fontFamily, AppType.brand);

    // Data slots.
    expect(t.bodyLarge?.fontFamily, AppType.data);
    expect(t.bodyMedium?.fontFamily, AppType.data);
    expect(t.bodySmall?.fontFamily, AppType.data);
    expect(t.labelMedium?.fontFamily, AppType.data);

    // Both carry the Bangla fallback so Bangla strings never render as tofu.
    for (final style in [t.titleLarge, t.bodyMedium]) {
      expect(style?.fontFamilyFallback, contains(AppType.bengali));
    }
  });

  testWidgets('Bangla locale stays on Kalpurush for every slot', (tester) async {
    final theme = AppTheme.light(const Locale('bn'));
    final t = theme.textTheme;

    for (final style in [
      t.displayLarge,
      t.headlineMedium,
      t.titleLarge,
      t.bodyLarge,
      t.bodyMedium,
      t.labelMedium,
    ]) {
      expect(
        style?.fontFamily,
        AppType.bengali,
        reason: 'Bangla must not fall back to a Latin-only family',
      );
    }
  });

  testWidgets('heading() applies SemiBold, body() preserves caller weight', (
    tester,
  ) async {
    final heading = AppType.heading(
      const TextStyle(fontSize: 28),
      locale: const Locale('en'),
    );
    expect(heading.fontFamily, AppType.brand);
    expect(heading.fontWeight, AppType.brandWeight);

    final body = AppType.body(
      const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
      locale: const Locale('en'),
    );
    expect(body.fontFamily, AppType.data);
    expect(body.fontWeight, FontWeight.w400);
  });
}