import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_1/core/app/app_update_gate.dart';
import 'package:inventory_1/core/localization/app_localizations.dart';
import 'package:inventory_1/core/models/app_update_policy.dart';
import 'package:inventory_1/core/services/app_update_installer.dart';
import 'package:inventory_1/core/services/app_update_service.dart';
import 'package:inventory_1/core/theme/app_theme.dart';
import 'package:pub_semver/pub_semver.dart';

final _installed = InstalledAppVersion(
  platform: 'android',
  packageName: 'com.mohajon.app',
  version: Version(1, 0, 0),
  buildNumber: 1,
);

AppUpdatePolicy _policy(bool enabled) => AppUpdatePolicy(
  platform: 'android',
  forceUpdateEnabled: enabled,
  minimumVersion: Version(1, 1, 0),
  minimumBuildNumber: 2,
  latestVersion: Version(1, 2, 0),
  latestBuildNumber: 3,
  updateUrl: 'https://play.google.com/store/apps/details?id=com.mohajon.app',
);

void main() {
  testWidgets(
    'authenticated content waits for policy and then opens when supported',
    (tester) async {
      final pending = Completer<AppUpdatePolicy>();
      await tester.pumpWidget(
        _app(
          AppUpdateGate(child: const Text('Shop home')),
          fetch: (_) => pending.future,
        ),
      );
      await tester.pump();
      expect(find.text('Shop home'), findsNothing);
      expect(find.text('Checking your app version…'), findsOneWidget);
      pending.complete(_policy(false));
      await tester.pumpAndSettle();
      expect(find.text('Shop home'), findsOneWidget);
    },
  );

  testWidgets(
    'mandatory update cannot be dismissed and a server disable releases it',
    (tester) async {
      var required = true;
      await tester.pumpWidget(
        _app(
          const AppUpdateGate(child: Text('Shop home')),
          fetch: (_) async => _policy(required),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Shop home'), findsNothing);
      expect(find.text('A new version is required'), findsOneWidget);
      expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
      await tester.tap(find.text('Update now'));
      await tester.pumpAndSettle();
      expect(find.text('Shop home'), findsNothing);
      expect(
        find.text('Complete the update in the store, then reopen Mohajon.'),
        findsOneWidget,
      );
      required = false;
      await tester.tap(find.text('Check again'));
      await tester.pumpAndSettle();
      expect(find.text('Shop home'), findsOneWidget);
    },
  );

  for (final locale in [const Locale('bn'), const Locale('en')]) {
    testWidgets(
      'required update fits a narrow phone with large ${locale.languageCode} text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          _app(
            RequiredUpdateScreen(
              decision: AppUpdateDecision(
                installed: _installed,
                policy: _policy(true),
              ),
              onUpdate: () {},
              onRetry: () {},
            ),
            locale: locale,
            scale: 2,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(FilledButton), findsOneWidget);
      },
    );
  }
}

Widget _app(
  Widget child, {
  Future<AppUpdatePolicy> Function(String)? fetch,
  Locale locale = const Locale('en'),
  double scale = 1,
}) {
  return ProviderScope(
    overrides: [
      appUpdateServiceProvider.overrideWithValue(
        AppUpdateService(
          loadInstalled: () async => _installed,
          readCached: (_) => null,
          fetchPolicy: fetch ?? (_) async => _policy(false),
          savePolicy: (_) async {},
        ),
      ),
      appUpdateInstallerProvider.overrideWithValue(
        AppUpdateInstaller(
          checkPlay: () async =>
              throw PlatformException(code: 'ERROR_API_NOT_AVAILABLE'),
          openExternal: (_) async => true,
        ),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light(locale),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: child,
    ),
  );
}
