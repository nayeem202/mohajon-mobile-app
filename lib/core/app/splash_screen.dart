import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../localization/app_localizations.dart';
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
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.isAnonymous) {
        await ref.read(syncStateProvider.notifier).syncNow();
      }
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (mounted) {
        final signedInUser = FirebaseAuth.instance.currentUser;
        final shopId = ref.read(shopIdProvider);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => signedInUser == null || signedInUser.isAnonymous
                ? const LoginScreen()
                : AppShell(key: ValueKey(shopId)),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF97316),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/brand/haalkhata_icon_1024.png',
              width: 88,
              height: 88,
            ),
            const SizedBox(height: 20),
            Text(
              l10n.t('appName'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.t('offlineReady'),
              style: const TextStyle(
                color: Color(0xFFFFD6A5),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
