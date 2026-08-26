import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import '../constants/app_constants.dart';
import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';
import 'app_providers.dart';
import 'splash_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/investments/providers/investment_providers.dart';
import '../services/fcm_service.dart';

class PosInventoryApp extends ConsumerWidget {
  PosInventoryApp({super.key});

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(investmentProfitSyncProvider);
    ref.listen(authStateProvider, (previous, next) {
      if (next.value != null) {
        unawaited(() async {
          final fcm = ref.read(fcmServiceProvider);
          await fcm.initialize();
          await fcm.refreshRegistration();
        }());
      }
      // Session was wiped (refresh token rejected) — route to login with a
      // clear message instead of leaving 403 errors all over the app.
      if (previous?.value != null && next.value == null) {
        final navigator = _navigatorKey.currentState;
        if (navigator != null) {
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
          );
          final messenger = ScaffoldMessenger.of(
            _navigatorKey.currentContext!,
          );
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Session expired. Please sign in again.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: AppConstants.appName,
      theme: AppTheme.light(),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SplashScreen(),
    );
  }
}
