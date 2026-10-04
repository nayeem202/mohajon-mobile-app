import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_1/features/auth/presentation/auth_brand.dart';
import 'package:inventory_1/features/auth/presentation/email_verification_dialog.dart';

/// Diagnostic: at the real device metrics (1220x2712 @ 2.8125 => 433.8x964.3
/// logical), find which soft-keyboard heights make the verification dialog
/// overflow, and report the exact magnitude Flutter complains about.
void main() {
  const physical = Size(1220, 2712);
  const dpr = 2.8125;

  Future<void> pumpDialog(
    WidgetTester tester, {
    required double keyboardPhysical,
    required bool keyboardUpBeforeOpen,
  }) async {
    tester.view.physicalSize = physical;
    tester.view.devicePixelRatio = dpr;
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
                      email: 'nayeem.ahmedemba@gmail.com',
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

    if (keyboardUpBeforeOpen) {
      tester.view.viewInsets = FakeViewPadding(bottom: keyboardPhysical);
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    if (!keyboardUpBeforeOpen) {
      tester.view.viewInsets = FakeViewPadding(bottom: keyboardPhysical);
      await tester.pumpAndSettle();
    }
  }

  testWidgets('sweep keyboard heights for overflow', (tester) async {
    const heights = <double>[800, 1000];

    for (final h in heights) {
      // Fresh view per iteration.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      // Capture the full FlutterErrorDetails (overflow diagnostics incl. the
      // widget chain and the offending constraints).
      final reports = <String>[];
      final prevOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        reports.add(details.toString());
      };
      addTearDown(() => FlutterError.onError = prevOnError);

      await pumpDialog(
        tester,
        keyboardPhysical: h,
        keyboardUpBeforeOpen: true,
      );

      tester.takeException();
      FlutterError.onError = prevOnError;

      final logical = h / dpr;
      for (final r in reports) {
        // ignore: avoid_print
        print('==== keyboard=${h.toStringAsFixed(0)}px '
            '(${logical.toStringAsFixed(0)} logical) ====');
        // ignore: avoid_print
        print(r);
      }
      if (reports.isEmpty) {
        // ignore: avoid_print
        print('==== keyboard=${h.toStringAsFixed(0)}px -> no report ====');
      }
    }
  });
}