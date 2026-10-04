import 'dart:math';

/// Generates an internal-use EAN-13 code for products that do not have a
/// manufacturer barcode. The 200 prefix is reserved for in-store/internal
/// numbering and is not presented as an official GS1 manufacturer code.
class ProductBarcodeGenerator {
  ProductBarcodeGenerator._();

  static final Random _random = Random.secure();

  static String generateInternalEan13() {
    final serial = _random.nextInt(1000000000).toString().padLeft(9, '0');
    final data = '200$serial';
    var sum = 0;
    for (var index = 0; index < data.length; index++) {
      final digit = int.parse(data[index]);
      sum += index.isEven ? digit : digit * 3;
    }
    final checkDigit = (10 - (sum % 10)) % 10;
    return '$data$checkDigit';
  }
}
