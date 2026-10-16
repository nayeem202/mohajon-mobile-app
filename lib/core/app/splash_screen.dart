import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../constants/app_constants.dart';
import 'app_providers.dart';
import 'authenticated_entry.dart';
import 'quick_tour_screen.dart';
import 'splash_branding.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  final _brandingReady = Completer<void>();

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      // Startup must have a hard upper bound. A corrupted/locked secure
      // storage or a slow local Hive operation must never leave the user on
      // the splash screen forever. Falling back to login is safe: no
      // business data is cleared and the stored session can be retried.
      var signedIn = false;
      try {
        signedIn = await ref
            .read(authServiceProvider)
            .restoreSession()
            .timeout(const Duration(seconds: 6), onTimeout: () => false);
      } catch (_) {
        signedIn = false;
      }
      if (signedIn && mounted) {
        // Refresh data in the background instead of blocking the UI, so
        // relaunching the app enters the home screen immediately.
        unawaited(ref.read(syncStateProvider.notifier).syncNow());
      }
      await _brandingReady.future;
      if (!mounted) return;
      await WidgetsBinding.instance.waitUntilFirstFrameRasterized;
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (mounted) {
        final session = ref.read(authStateProvider).value;
        final Widget next;
        if (session != null) {
          next = const AuthenticatedEntry();
        } else {
          final hasSeenOnboarding =
              Hive.box(
                    HiveBoxes.settings,
                  ).get('hasSeenOnboarding', defaultValue: false)
                  as bool;
          next = hasSeenOnboarding
              ? const LoginScreen()
              : const QuickTourScreen();
        }
        Navigator.of(context).pushReplacement(
          PageRouteBuilder<void>(
            pageBuilder: (context, animation, secondaryAnimation) => next,
            transitionDuration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 220),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    if (!_brandingReady.isCompleted) _brandingReady.complete();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SplashBranding(
      onReady: () {
        if (!_brandingReady.isCompleted) _brandingReady.complete();
      },
    );
  }
}
