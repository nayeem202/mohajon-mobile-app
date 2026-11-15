import '../utils/money.dart';

/// Shared checkout/receipt calculation, matching SaleService's write boundary:
/// round each line, subtract discount, then apply VAT to the discounted goods.
class InvoiceTotals {
  const InvoiceTotals._(
    this.subtotal,
    this.taxableAmount,
    this.vatAmount,
    this.total,
  );

  factory InvoiceTotals.calculate({
    required Iterable<double> lineTotals,
    double discount = 0,
    double vatPercent = 0,
    double charge = 0,
  }) {
    final subtotal = moneyRound2(
      lineTotals.fold<double>(0, (sum, line) => sum + moneyRound2(line)),
    );
    final taxable = moneyRound2(
      (subtotal - moneyRound2(discount)).clamp(0, double.infinity),
    );
    final vat = moneyRound2(taxable * vatPercent / 100);
    return InvoiceTotals._(
      subtotal,
      taxable,
      vat,
      moneyRound2(taxable + vat + moneyRound2(charge)),
    );
  }

  final double subtotal;
  final double taxableAmount;
  final double vatAmount;
  final double total;
}
