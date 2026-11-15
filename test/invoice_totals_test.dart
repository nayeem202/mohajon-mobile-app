import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_1/core/models/invoice_totals.dart';
import 'package:inventory_1/core/models/sale.dart';
import 'package:inventory_1/features/pos/providers/cart_provider.dart';

void main() {
  test('POS-03 round each line before subtotal, like Java SaleService', () {
    final totals = InvoiceTotals.calculate(lineTotals: [0.335, 0.335]);
    expect(totals.subtotal, 0.68);
    expect(totals.total, 0.68);
  });
  test('POS-03 charge is rounded and added after VAT', () {
    final totals = InvoiceTotals.calculate(
      lineTotals: [200],
      discount: 20,
      vatPercent: 5,
      charge: 2.555,
    );
    expect(totals.taxableAmount, 180);
    expect(totals.vatAmount, 9);
    expect(totals.total, 191.56);
  });
  test(
    'POS-03 checkout preview, saved sale and receipt use identical totals',
    () {
      const cart = CartState(
        items: [
          SaleItem(
            productId: 'p',
            name: 'Item',
            qty: 2,
            unitPrice: 100,
            purchasePrice: 80,
          ),
        ],
        discount: 20,
        vatPercent: 5,
      );
      final sale = Sale(
        saleId: 'sale',
        customerId: 'customer',
        items: cart.items,
        discount: cart.discount,
        vatPercent: cart.vatPercent,
        totalAmount: cart.total,
        paidAmount: 0,
        dueAmount: cart.total,
        paymentStatus: PaymentStatus.due,
        shopId: 'qa-shop',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final restored = Sale.fromJson(sale.toJson());
      expect(restored.invoiceTotals.vatAmount, cart.vatAmount);
      expect(restored.invoiceTotals.total, 189);
      expect(restored.totalAmount, restored.invoiceTotals.total);
    },
  );
}
