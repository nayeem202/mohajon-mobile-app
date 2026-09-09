import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:inventory_1/core/app/pos_inventory_app.dart';
import 'package:inventory_1/core/constants/app_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App shell renders dashboard', (tester) async {
    await Hive.initFlutter();
    await Hive.openBox<Map>(HiveBoxes.products);
    await Hive.openBox<Map>(HiveBoxes.customers);
    await Hive.openBox<Map>(HiveBoxes.sales);
    await Hive.openBox<Map>(HiveBoxes.payments);
    await Hive.openBox<Map>(HiveBoxes.purchases);
    await Hive.openBox<Map>(HiveBoxes.suppliers);
    await Hive.openBox<Map>(HiveBoxes.users);
    await Hive.openBox<dynamic>(HiveBoxes.settings);

    await tester.pumpWidget(ProviderScope(child: PosInventoryApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.dashboard_outlined), findsOneWidget);
    expect(find.text('Dashboard'), findsWidgets);
  });
}
