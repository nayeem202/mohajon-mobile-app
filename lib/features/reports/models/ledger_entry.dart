class LedgerEntry {
  const LedgerEntry({
    required this.date,
    required this.particulars,
    this.debit = 0,
    this.credit = 0,
    required this.balance,
  });

  final DateTime date;
  final String particulars;
  final double debit;
  final double credit;
  final double balance;
}
