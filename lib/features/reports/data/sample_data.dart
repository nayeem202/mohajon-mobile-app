import '../models/customer_ledger.dart';
import '../models/ledger_entry.dart';

final sampleCustomers = [
  CustomerLedger(name: 'Rahim Uddin', phone: '+8801711-234567', debit: 48750, credit: 48750),
  CustomerLedger(name: 'Fatema Begum', phone: '+8801712-345678', debit: 8900, credit: 6600),
  CustomerLedger(name: 'Shamim Hossain', phone: '+8801713-456789', debit: 28900, credit: 28900),
  CustomerLedger(name: 'Kamal Mia', phone: '+8801714-567890', debit: 13200, credit: 9900),
  CustomerLedger(name: 'Nusrat Jahan', phone: '+8801715-678901', debit: 35200, credit: 35200),
  CustomerLedger(name: 'Abdur Rahim', phone: '+8801716-789012', debit: 7500, credit: 7500),
  CustomerLedger(name: 'Shahida Begum', phone: '+8801717-890123', debit: 18900, credit: 15100),
  CustomerLedger(name: 'Faruk Ahmed', phone: '+8801718-901234', debit: 8200, credit: 7400),
  CustomerLedger(name: 'Jahanara Khatun', phone: '+8801719-012345', debit: 45600, credit: 45600),
  CustomerLedger(name: 'Mizanur Rahman', phone: '+8801720-123456', debit: 10100, credit: 8400),
  CustomerLedger(name: 'Rokeya Sultana', phone: '+8801721-234567', debit: 6200, credit: 6200),
  CustomerLedger(name: 'Hasan Ali', phone: '+8801722-345678', debit: 27400, credit: 22100),
  CustomerLedger(name: 'Parvin Akhter', phone: '+8801723-456789', debit: 14200, credit: 14200),
];

double get maxCustomerAmount {
  double max = 0;
  for (final c in sampleCustomers) {
    final m = math_max(c.debit, c.credit);
    if (m > max) max = m;
  }
  return max;
}

double math_max(double a, double b) => a > b ? a : b;

List<CustomerLedger> customerLedgersWithMax() {
  final max = maxCustomerAmount;
  return sampleCustomers
      .map((c) => CustomerLedger(
            name: c.name,
            phone: c.phone,
            debit: c.debit,
            credit: c.credit,
            maxAmount: max,
          ))
      .toList();
}

final _jul1 = DateTime(2026, 7, 1);
final _jul3 = DateTime(2026, 7, 3);
final _jul5 = DateTime(2026, 7, 5);
final _jul7 = DateTime(2026, 7, 7);
final _jul8 = DateTime(2026, 7, 8);
final _jul10 = DateTime(2026, 7, 10);

final rahimLedgerEntries = [
  LedgerEntry(date: _jul1, particulars: 'Opening Balance', balance: 0),
  LedgerEntry(date: _jul3, particulars: 'Purchase Invoice', debit: 2450, balance: 2450),
  LedgerEntry(date: _jul3, particulars: 'Payment Received', credit: 2450, balance: 0),
  LedgerEntry(date: _jul5, particulars: 'Purchase Invoice', debit: 1800, balance: 1800),
  LedgerEntry(date: _jul5, particulars: 'Payment Received', credit: 1800, balance: 0),
  LedgerEntry(date: _jul7, particulars: 'Purchase Invoice', debit: 5100, balance: 5100),
  LedgerEntry(date: _jul7, particulars: 'Payment Received', credit: 5100, balance: 0),
  LedgerEntry(date: _jul8, particulars: 'Purchase Invoice', debit: 3200, balance: 3200),
  LedgerEntry(date: _jul8, particulars: 'Payment Received', credit: 3200, balance: 0),
  LedgerEntry(date: _jul10, particulars: 'Purchase Invoice', debit: 2450, balance: 2450),
  LedgerEntry(date: _jul10, particulars: 'Payment Received', credit: 2450, balance: 0),
];
