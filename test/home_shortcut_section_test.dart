import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_1/features/dashboard/presentation/models/shortcut_model.dart';
import 'package:inventory_1/features/dashboard/presentation/widgets/home_shortcut_section.dart';
import 'package:inventory_1/features/dashboard/providers/shortcut_providers.dart';

void main() {
  testWidgets('lays out four shortcut cards with centered icons', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final shortcuts = allShortcutItems.take(4).toList();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [selectedShortcutsProvider.overrideWithValue(shortcuts)],
        child: const MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: HomeShortcutSection(),
            ),
          ),
        ),
      ),
    );

    for (final shortcut in shortcuts) {
      final card = find.byKey(ValueKey('shortcut-card-${shortcut.id}'));
      final icon = find.byKey(ValueKey('shortcut-icon-${shortcut.id}'));
      expect(card, findsOneWidget);
      expect(icon, findsOneWidget);
      expect(
        (tester.getCenter(card).dx - tester.getCenter(icon).dx).abs(),
        lessThan(0.5),
      );
    }

    expect(tester.takeException(), isNull);
  });
}
