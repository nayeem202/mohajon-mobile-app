import 'dart:math' as math;

class CustomerLedger {
  const CustomerLedger({
    required this.name,
    required this.phone,
    required this.debit,
    required this.credit,
    this.maxAmount,
  });

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
}
