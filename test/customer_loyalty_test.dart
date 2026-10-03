import 'package:flutter_test/flutter_test.dart';

import 'package:inventory_1/core/models/customer.dart';

void main() {
  test('customer loyalty points survive JSON round trip and edits', () {
    final customer = Customer(
      customerId: 'customer-1',
      name: 'Test Customer',
      phone: '01700000000',
      loyaltyPoints: 125,
      shopId: 'shop-1',
      updatedAt: DateTime(2026, 1, 1),
    );

    final restored = Customer.fromJson(customer.toJson());
    expect(restored.loyaltyPoints, 125);
    expect(restored.copyWith(loyaltyPoints: 90).loyaltyPoints, 90);
  });
}
