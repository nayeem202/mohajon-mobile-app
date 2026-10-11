import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_1/features/purchases/models/purchase_order.dart';
import 'package:inventory_1/features/purchases/models/purchase_receipt.dart';

void main() {
  group('Purchase receipt reconciliation', () {
    test('calculates shortage, expected invoice and variance', () {
      final receipt = PurchaseReceipt(
        receiptId: 'receipt-1',
        receivedAt: DateTime.utc(2026, 10, 9),
        invoiceNumber: 'INV-88',
        items: const [
          PurchaseReceiptItem(
            productId: 'rice',
            orderedQty: 10,
            deliveredQty: 9,
            acceptedQty: 8,
            damagedQty: 1,
            unitCost: 105,
            orderedUnitCost: 100,
          ),
        ],
        invoiceAmount: 820,
        freightAmount: 20,
        attachmentPath: '/offline/invoice.jpg',
      );

      expect(receipt.items.single.shortQty, 1);
      expect(receipt.expectedAmount, 820);
      expect(receipt.invoiceVariance, 0);
    });

    test(
      'round-trips receipt details and accepted/physically delivered totals',
      () {
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
          status: 'PARTIALLY_RECEIVED',
          shopId: 'shop-1',
          createdAt: DateTime.utc(2026, 10, 9),
          updatedAt: DateTime.utc(2026, 10, 9),
          receivedQty: const {'rice': 8},
          deliveredQty: const {'rice': 9},
          receipts: [
            PurchaseReceipt(
              receiptId: 'receipt-1',
              receivedAt: DateTime.utc(2026, 10, 9),
              items: const [
                PurchaseReceiptItem(
                  productId: 'rice',
                  orderedQty: 10,
                  deliveredQty: 9,
                  acceptedQty: 8,
                  damagedQty: 1,
                  unitCost: 105,
                  orderedUnitCost: 100,
                ),
              ],
              invoiceAmount: 820,
              freightAmount: 20,
              attachmentPath: '/offline/invoice.jpg',
            ),
          ],
        );

        final restored = PurchaseOrder.fromJson(order.toJson());
        expect(restored.receivedQty['rice'], 8);
        expect(restored.deliveredQty['rice'], 9);
        expect(restored.receipts.single.invoiceNumber, '');
        expect(restored.receipts.single.attachmentPath, '/offline/invoice.jpg');
        expect(restored.receipts.single.invoiceVariance, 0);
      },
    );

    test('legacy purchase orders treat accepted quantities as delivered', () {
      final order = PurchaseOrder.fromJson({
        'orderId': 'legacy',
        'supplierId': 'supplier-1',
        'items': [
          {'productId': 'rice', 'name': 'Rice', 'qty': 2, 'unitCost': 10},
        ],
        'totalAmount': 20,
        'status': 'PARTIALLY_RECEIVED',
        'shopId': 'shop-1',
        'createdAt': '2026-10-09T00:00:00.000Z',
        'updatedAt': '2026-10-09T00:00:00.000Z',
        'receivedQty': {'rice': 1},
      });

      expect(order.deliveredQty['rice'], 1);
      expect(order.receipts, isEmpty);
    });
  });
}
