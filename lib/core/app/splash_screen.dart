import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/providers/auth_providers.dart';
import 'app_providers.dart';
import 'app_shell.dart';

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
      final signedIn = await ref.read(authServiceProvider).restoreSession();
      if (signedIn) {
        await ref.read(syncStateProvider.notifier).syncNow();
      }
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (mounted) {
        final session = ref.read(authStateProvider).value;
        final shopId = ref.read(shopIdProvider);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => session == null
                ? const LoginScreen()
                : AppShell(key: ValueKey(shopId)),
          ),
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
