import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/app/app_bootstrap.dart';
import 'core/app/pos_inventory_app.dart';
import 'core/services/fcm_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _suppressKnownFrameworkAssertions();
  await AppBootstrap.init();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (_) {
    // Native Firebase files are added by `flutterfire configure`.
  }
  runApp(const ProviderScope(child: PosInventoryApp()));
}

void _suppressKnownFrameworkAssertions() {
  FlutterError.onError = (details) {
    if (details.exception.toString().contains("_dependents.isEmpty")) {
      return;
    }
    FlutterError.presentError(details);
  };
}
