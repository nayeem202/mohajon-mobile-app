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
  const VoiceBill({required this.items, required this.reply});

  final List<VoiceBillItem> items;
  final String reply;

  bool get hasMatches => items.isNotEmpty;
}