import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app/app_bootstrap.dart';
import 'core/app/pos_inventory_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _suppressKnownFrameworkAssertions();
  await AppBootstrap.init();
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
