import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_1/core/localization/app_localizations.dart';
import 'package:inventory_1/features/purchases/models/purchase_order.dart';
import 'package:inventory_1/features/purchases/presentation/purchase_receipt_dialog.dart';

void main() {
  final order = PurchaseOrder(
    orderId: 'order-1',
    supplierId: 'supplier-1',
    items: const [
      PurchaseOrderItem(
        productId: 'rice',
        name: 'Rice',
        qty: 10,
        unitCost: 100,
      ),
    ],
    totalAmount: 1000,
    status: 'ORDERED',
    shopId: 'shop-1',
    createdAt: DateTime.utc(2026, 10, 9),
    updatedAt: DateTime.utc(2026, 10, 9),
  );

  for (final width in [320.0, 360.0, 414.0]) {
    testWidgets('receipt dialog fits a ${width.toInt()}dp phone width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showPurchaseReceiptDialog(context, order),
                  child: const Text('Open receipt'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ElevatedButton), findsOneWidget);
      await tester.tap(find.text('Open receipt'));
      await tester.pumpAndSettle();

      expect(find.text('Check delivered items'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
