import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/app/app_bootstrap.dart';
import 'core/app/pos_inventory_app.dart';
import 'core/services/fcm_service.dart';
import 'core/services/secure_tokens.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _suppressKnownFrameworkAssertions();
  debugPrint('Startup: loading secure session');
  await TokenStore.load();
  debugPrint('Startup: secure session ready');

  debugPrint('Startup: opening local database');
  await AppBootstrap.init();
  debugPrint('Startup: local database ready');

  // The app must be usable even when the optional push-notification SDK is
  // slow to respond. Initialise it after the first Flutter frame instead of
  // holding Android's native launch screen open indefinitely.
  runApp(ProviderScope(child: PosInventoryApp()));
  unawaited(_initializeFirebase());
}

Future<void> _initializeFirebase() async {
  try {
    debugPrint('Startup: initializing Firebase');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 10));
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    debugPrint('Startup: Firebase ready');
  } catch (error) {
    debugPrint('Startup: Firebase skipped ($error)');
    // Native Firebase files are added by `flutterfire configure`.
  }
}

void _suppressKnownFrameworkAssertions() {
  FlutterError.onError = (details) {
    if (details.exception.toString().contains("_dependents.isEmpty")) {
      return;
    }
    FlutterError.presentError(details);
  };
}
