import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_1/core/localization/app_localizations.dart';

void main() {
  testWidgets('localized app smoke test completes cleanly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Text(AppLocalizations.of(context).t('appName')),
          ),
        ),
      ),
    );

    expect(find.text('Mohajon'), findsOneWidget);
    await tester.pump();
  });
}
