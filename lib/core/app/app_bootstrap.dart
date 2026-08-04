import 'package:hive_flutter/hive_flutter.dart';

import '../constants/app_constants.dart';

class AppBootstrap {
  const AppBootstrap._();

  /// Firebase is no longer used by the app: authentication is handled by the
  /// auth service and business data by the Haalkhata service. The flag stays
  /// for the legacy Firebase auth backend, which is never active by default.
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
      Hive.openBox<Map>(HiveBoxes.vendors),
      Hive.openBox<Map>(HiveBoxes.vendorPurchases),
      Hive.openBox<Map>(HiveBoxes.vendorPayments),
      Hive.openBox<Map>(HiveBoxes.investments),
      Hive.openBox<Map>(HiveBoxes.expenses),
      Hive.openBox<Map>(HiveBoxes.users),
      Hive.openBox<dynamic>(HiveBoxes.settings),
    ]);
  }
}
