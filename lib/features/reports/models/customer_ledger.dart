import 'dart:math' as math;

enum LedgerStatus { settled, due, advance }

class CustomerLedger {
  const CustomerLedger({
    required this.customerId,
    required this.name,
    required this.phone,
    required this.debit,
    required this.credit,
    this.maxAmount,
  });

  final String customerId;
  final String name;
  final String phone;
  final double debit;
  final double credit;
  final double? maxAmount;

  double get balance => debit - credit;

  double get debitFraction => maxAmount != null && maxAmount! > 0
      ? debit / math.max(maxAmount!, credit)
      : 0;

  double get creditFraction => maxAmount != null && maxAmount! > 0
      ? credit / math.max(maxAmount!, debit)
      : 0;

  bool get hasDue => balance > 0;

  double get absoluteBalance => balance.abs();

  LedgerStatus get status {
    if (balance.abs() < 1) return LedgerStatus.settled;
    return balance > 0 ? LedgerStatus.due : LedgerStatus.advance;
  }
}
