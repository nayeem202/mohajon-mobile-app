import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_1/features/voice_assistant/models/voice_bill.dart';

void main() {
  for (final quantity in [
    0.0,
    -1.0,
    0.5,
    double.nan,
    double.infinity,
    2147483648.0,
  ]) {
    test('POS-02 voice result $quantity cannot partially mutate a cart', () {
      final item = VoiceBillItem(
        productId: 'p',
        nameEn: 'Rice',
        nameBn: 'চাল',
        quantity: quantity,
        sellingPrice: 100,
        stockQty: 10,
        unit: 'pcs',
      );
      expect(item.hasValidCartQuantity, isFalse);
    });
  }
  test('positive whole-number voice result matches API stock contract', () {
    const item = VoiceBillItem(
      productId: 'p',
      nameEn: 'Rice',
      nameBn: 'চাল',
      quantity: 2,
      sellingPrice: 100,
      stockQty: 10,
      unit: 'pcs',
    );
    expect(item.hasValidCartQuantity, isTrue);
  });
}
