enum LedgerEntryType { sale, payment, debit, credit }

class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.createdAt,
    required this.description,
  });

  final String id;
  final LedgerEntryType type;
  final double amount;
  final DateTime createdAt;
  final String description;

  double get signedAmount {
    switch (type) {
      case LedgerEntryType.sale:
      case LedgerEntryType.debit:
        return amount;
      case LedgerEntryType.payment:
      case LedgerEntryType.credit:
        return -amount;
    }
  }

  bool get isDebit => signedAmount > 0;
  bool get isCredit => signedAmount < 0;
}
