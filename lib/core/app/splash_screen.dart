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

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
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
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (mounted) {
        final session = ref.read(authStateProvider).value;
        final Widget next;
        if (session != null) {
          next = const AuthenticatedEntry();
        } else {
          final hasSeenOnboarding =
              Hive.box(HiveBoxes.settings).get('hasSeenOnboarding', defaultValue: false) as bool;
          next = hasSeenOnboarding ? const LoginScreen() : const QuickTourScreen();
        }
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => next),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/brand/mohajon.png',
              width: 180,
              height: 180,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 12),
            Text(
              'মহাজন',
              style: const TextStyle(
                color: Color(0xFF2F3028),
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'আপনার ব্যবসার হিসাবের সঙ্গী',
              style: const TextStyle(
                color: Color(0xFF77735F),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFC800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
