import 'package:flutter_test/flutter_test.dart';

import 'package:inventory_1/core/models/sale.dart';
import 'package:inventory_1/core/models/sale_return.dart';

void main() {
  test('sale item preserves stable identity and batch allocations', () {
    const item = SaleItem(
      saleItemId: 'sale-item-1',
      productId: 'product-1',
      name: 'Cream',
      qty: 2,
      unitPrice: 120,
      purchasePrice: 80,
      batchAllocations: [
        SaleBatchAllocation(batchId: 'batch-1', quantity: 2),
      ],
    );

    final restored = SaleItem.fromJson(item.toJson());
    expect(restored.saleItemId, 'sale-item-1');
    expect(restored.batchAllocations.single.batchId, 'batch-1');
    expect(restored.batchAllocations.single.quantity, 2);
  });

  test('sale return round-trips through sync JSON', () {
    final now = DateTime(2026, 1, 2, 3, 4, 5);
    final value = SaleReturn(
      returnId: 'return-1',
      saleId: 'sale-1',
      customerId: 'customer-1',
      items: const [
        SaleReturnItem(
          returnItemId: 'return-item-1',
          saleItemId: 'sale-item-1',
          productId: 'product-1',
          name: 'Cream',
          qty: 1,
          unitPrice: 120,
          purchasePrice: 80,
        ),
      ],
      refundAmount: 120,
      refundMethod: 'CASH',
      reason: 'Damaged pack',
      staffId: 'staff-1',
      branchId: 'branch-1',
      shopId: 'shop-1',
      createdAt: now,
      updatedAt: now,
    );

    final restored = SaleReturn.fromJson(value.toJson());
    expect(restored.returnId, value.returnId);
    expect(restored.items.single.saleItemId, 'sale-item-1');
    expect(restored.refundAmount, 120);
    expect(restored.branchId, 'branch-1');
  });
}
