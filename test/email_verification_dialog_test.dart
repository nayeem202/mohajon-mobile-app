import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_1/features/auth/presentation/auth_brand.dart';
import 'package:inventory_1/features/auth/presentation/email_verification_dialog.dart';

/// The verification dialog is taller than the space the soft keyboard leaves,
/// so it must scroll rather than overflow. RenderFlex overflows are reported as
/// test failures, so these assert the real layout at a realistic phone size.
void main() {
  Future<void> pumpDialog(
    WidgetTester tester, {
    required double keyboardHeight,
  }) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AuthBrand.theme(ThemeData()),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: Consumer(
                  builder: (context, ref, _) => TextButton(
                    onPressed: () => showEmailVerificationDialog(
                      context,
                      ref,
                      email: 'someone@example.com',
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    tester.view.viewInsets = FakeViewPadding(bottom: keyboardHeight);
    await tester.pumpAndSettle();
  }

  testWidgets('fits without a keyboard', (tester) async {
    await pumpDialog(tester, keyboardHeight: 0);
    expect(find.text('Verify your email'), findsOneWidget);
  });

  testWidgets('does not overflow with a tall keyboard', (tester) async {
    await pumpDialog(tester, keyboardHeight: 1100);
    expect(find.text('Verify your email'), findsOneWidget);
  });

  testWidgets('code field stays reachable with the keyboard up', (
    tester,
  ) async {
    await pumpDialog(tester, keyboardHeight: 1100);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pumpAndSettle();
    expect(find.text('123456'), findsOneWidget);
  });
}