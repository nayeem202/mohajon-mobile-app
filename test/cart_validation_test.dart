import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_1/core/models/product.dart';
import 'package:inventory_1/core/models/sale.dart';
import 'package:inventory_1/features/pos/providers/cart_provider.dart';

void main() {
  test(
    'POS-03 VAT is calculated after discount, matching the Java invoice',
    () {
      final cart = CartState(
        items: [
          SaleItem(
            productId: 'p1',
            name: 'Rice',
            qty: 2,
            unitPrice: 100,
            purchasePrice: 80,
          ),
        ],
        discount: 20,
        vatPercent: 5,
        paidAmount: 100,
      );
      expect(cart.subtotal, 200);
      expect(cart.vatAmount, 9);
      expect(cart.total, 189);
      expect(cart.due, 89);
    },
  );

  test('POS-03 monetary arithmetic rounds at paisa boundaries', () {
    final cart = CartState(
      items: [
        SaleItem(
          productId: 'p1',
          name: 'Item',
          qty: 3,
          unitPrice: 19.99,
          purchasePrice: 10,
        ),
      ],
      discount: 0.17,
      vatPercent: 5,
      paidAmount: 50,
    );
    expect(cart.subtotal, 59.97);
    expect(cart.vatAmount, 2.99);
    expect(cart.total, 62.79);
    expect(cart.due, 12.79);
  });

  group('POS-01/02 cart input integrity', () {
    late ProviderContainer container;
    late CartController controller;
    setUp(() {
      container = ProviderContainer();
      controller = container.read(cartProvider.notifier);
      controller.addProduct(
        Product(
          productId: 'p1',
          nameEn: 'Rice',
          nameBn: 'চাল',
          barcode: '',
          category: 'Rice',
          unit: 'piece',
          purchasePrice: 80,
          sellingPrice: 100,
          stockQty: 10,
          lowStockAlert: 2,
          shopId: 'qa-shop',
          updatedAt: DateTime(2026, 10, 22),
        ),
      );
    });
    tearDown(() => container.dispose());

    test('repeated adds keep one item and quantity zero removes it', () {
      controller.addProduct(
        Product(
          productId: 'p1',
          nameEn: 'Rice',
          nameBn: 'চাল',
          barcode: '',
          category: 'Rice',
          unit: 'piece',
          purchasePrice: 80,
          sellingPrice: 100,
          stockQty: 10,
          lowStockAlert: 2,
          shopId: 'qa-shop',
          updatedAt: DateTime(2026, 10, 22),
        ),
      );
      expect(container.read(cartProvider).items.single.qty, 2);
      controller.setQty('p1', 0);
      expect(container.read(cartProvider).items, isEmpty);
    });

    for (final value in [double.nan, double.infinity, -double.infinity]) {
      test('rejects nonfinite quantity $value without changing the cart', () {
        expect(() => controller.setQty('p1', value), throwsArgumentError);
        expect(container.read(cartProvider).items.single.qty, 1);
      });
    }
    test('rejects fractional quantity unsupported by server integer stock', () {
      expect(() => controller.setQty('p1', 1.5), throwsArgumentError);
      expect(container.read(cartProvider).items.single.qty, 1);
    });
    for (final value in [-1.0, double.nan, double.infinity]) {
      test('rejects invalid discount/payment $value', () {
        expect(() => controller.setDiscount(value), throwsArgumentError);
        expect(() => controller.setPaidAmount(value), throwsArgumentError);
        expect(container.read(cartProvider).discount, 0);
        expect(container.read(cartProvider).paidAmount, 0);
      });
    }
    for (final value in [-1.0, 100.01, double.nan, double.infinity]) {
      test('rejects VAT outside finite 0..100: $value', () {
        expect(() => controller.setVatPercent(value), throwsArgumentError);
        expect(container.read(cartProvider).vatPercent, 5);
      });
    }
    test('negative loyalty redemption cannot enter the cart', () {
      expect(
        () => controller.setLoyaltyPointsRedeemed(-1),
        throwsArgumentError,
      );
      expect(container.read(cartProvider).loyaltyPointsRedeemed, 0);
    });
    test('empty checkout cannot reach storage', () async {
      controller.clear();
      await expectLater(controller.checkout(), throwsStateError);
    });
    test('due without customer cannot reach storage', () async {
      await expectLater(controller.checkout(), throwsStateError);
    });
  });
}
