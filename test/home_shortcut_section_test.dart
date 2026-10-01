import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_1/features/dashboard/presentation/models/shortcut_model.dart';
import 'package:inventory_1/features/dashboard/presentation/widgets/home_shortcut_section.dart';
import 'package:inventory_1/features/dashboard/providers/shortcut_providers.dart';

void main() {
  testWidgets('lays out shortcuts on narrow and regular phone widths', (
    tester,
  ) async {
    final shortcuts = allShortcutItems.take(4).toList();
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in [const Size(240, 320), const Size(320, 568), const Size(390, 700)]) {
      await tester.binding.setSurfaceSize(size);
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
      await tester.pumpAndSettle();

      for (final shortcut in shortcuts) {
        final icon = find.byKey(ValueKey('shortcut-icon-${shortcut.id}'));
        expect(icon, findsOneWidget);
      }

      expect(tester.takeException(), isNull);
    }
  });
}
