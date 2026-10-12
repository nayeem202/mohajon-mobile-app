import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:inventory_1/core/app/app_providers.dart';
import 'package:inventory_1/core/constants/app_constants.dart';
import 'package:inventory_1/core/localization/app_localizations.dart';
import 'package:inventory_1/core/offline/local_database.dart';
import 'package:inventory_1/features/voice_assistant/presentation/hambot_sheet.dart';

void main() {
  late Directory hiveDirectory;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    hiveDirectory = await Directory.systemTemp.createTemp('mohajon-ai-layout');
    Hive.init(hiveDirectory.path);
    for (final name in const [
      HiveBoxes.products,
      HiveBoxes.customers,
      HiveBoxes.sales,
      HiveBoxes.payments,
      HiveBoxes.customerLedgerEntries,
      HiveBoxes.purchases,
      HiveBoxes.purchaseOrders,
      HiveBoxes.suppliers,
      HiveBoxes.users,
      HiveBoxes.vendors,
      HiveBoxes.vendorPurchases,
      HiveBoxes.vendorPayments,
      HiveBoxes.expenses,
      HiveBoxes.stockAdjustments,
      HiveBoxes.supplierReturns,
      HiveBoxes.auditEvents,
      HiveBoxes.productBatches,
      HiveBoxes.saleReturns,
      HiveBoxes.notifications,
    ]) {
      await Hive.openBox<Map>(name);
    }
    await Hive.openBox<dynamic>(HiveBoxes.settings);
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  testWidgets('Mohajon AI sheet fits narrow widths in both app languages', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = LocalDatabase();

    for (final language in const ['en', 'bn']) {
      for (final width in const [280.0, 320.0, 360.0]) {
        await tester.binding.setSurfaceSize(Size(width, 760));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [localDatabaseProvider.overrideWithValue(database)],
            child: MaterialApp(
              locale: Locale(language),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.2)),
                child: child!,
              ),
              home: const Scaffold(body: HambotSheet()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Mohajon AI'), findsNWidgets(2));
        expect(
          tester.takeException(),
          isNull,
          reason: '$language at $width px',
        );
      }
    }
  });
}
