class VoiceBillItem {
  const VoiceBillItem({
    required this.productId,
    required this.nameEn,
    required this.nameBn,
    required this.quantity,
    required this.sellingPrice,
    required this.stockQty,
    required this.unit,
  });

  final String productId;
  final String nameEn;
  final String nameBn;
  final double quantity;
  final double sellingPrice;
  final int stockQty;
  final String unit;

  // Inventory and the Java sale API currently use whole-number stock units.
  bool get hasValidCartQuantity =>
      quantity.isFinite &&
      quantity > 0 &&
      quantity <= 2147483647 &&
      quantity == quantity.truncateToDouble();

  VoiceBillItem copyWith({double? quantity}) => VoiceBillItem(
    productId: productId,
    nameEn: nameEn,
    nameBn: nameBn,
    quantity: quantity ?? this.quantity,
    sellingPrice: sellingPrice,
    stockQty: stockQty,
    unit: unit,
  );
}

class VoiceBill {
  const VoiceBill({
    required this.items,
    required this.reply,
    this.transcript = '',
  });

  final List<VoiceBillItem> items;
  final String reply;
  final String transcript;

  bool get hasMatches => items.isNotEmpty;

  VoiceBill copyWithTranscript(String transcript) =>
      VoiceBill(items: items, reply: reply, transcript: transcript);
}
