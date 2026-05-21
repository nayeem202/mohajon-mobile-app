import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../constants/app_constants.dart';
import '../../firebase_options.dart';

class AppBootstrap {
  const AppBootstrap._();

  static bool firebaseReady = false;

  static Future<void> init() async {
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox<Map>(HiveBoxes.products),
      Hive.openBox<Map>(HiveBoxes.customers),
      Hive.openBox<Map>(HiveBoxes.sales),
      Hive.openBox<Map>(HiveBoxes.payments),
      Hive.openBox<Map>(HiveBoxes.customerLedgerEntries),
      Hive.openBox<Map>(HiveBoxes.purchases),
      Hive.openBox<Map>(HiveBoxes.suppliers),
      Hive.openBox<Map>(HiveBoxes.users),
      Hive.openBox<Map>(HiveBoxes.syncQueue),
      Hive.openBox<dynamic>(HiveBoxes.settings),
    ]);

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      if (FirebaseAuth.instance.currentUser?.isAnonymous ?? false) {
        await FirebaseAuth.instance.signOut();
      }
      firebaseReady = true;
    } catch (_) {
      firebaseReady = false;
    }
  }
}
