import '../../../core/models/customer.dart';
import '../../../core/models/customer_ledger_entry.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/product.dart';
import '../../../core/models/sale.dart';
import '../../../core/offline/local_database.dart';
import '../../../core/utils/money.dart';
import '../../expenses/models/expense.dart';

/// Answers common business questions directly from the shop's locally stored
/// records. These answers work offline and never ask an LLM to calculate a
/// business number, which makes the result both free and verifiable.
class VerifiedBusinessAnswerService {
  const VerifiedBusinessAnswerService._();

  static VerifiedBusinessAnswer? answer(
    LocalDatabase db, {
    required String shopId,
    required String question,
    required String languageCode,
    DateTime? now,
  }) {
    final query = _normalise(question);
    if (query.isEmpty) return null;
    final snapshot = _BusinessSnapshot.fromDatabase(
      db,
      shopId: shopId,
      now: now ?? DateTime.now(),
    );
    final isBangla = languageCode == 'bn';

    if (_containsAny(query, const [
      'baki',
      'due',
      'paona',
      'pawna',
      'pao na',
      'debt',
      'credit',
      'বাকি',
      'পাওনা',
    ])) {
      return _dueAnswer(snapshot, query, isBangla);
    }
    if (_containsAny(query, const ['lav', 'profit', 'gross profit', 'লাভ'])) {
      return _profitAnswer(snapshot, query, isBangla);
    }
    if (_containsAny(query, const ['khoroch', 'expense', 'cost', 'খরচ'])) {
      return _expenseAnswer(snapshot, query, isBangla);
    }
    if (_containsAny(query, const [
      'top sell',
      'best sell',
      'beshi bikri',
      'most sold',
      'popular',
      'বেশি বিক্রি',
      'জনপ্রিয়',
    ])) {
      return _topProductAnswer(snapshot, isBangla);
    }
    if (_containsAny(query, const [
      'stock',
      'stok',
      'inventory',
      'কম আছে',
      'স্টক',
      'মজুদ',
    ])) {
      return _stockAnswer(snapshot, query, isBangla);
    }
    if (_containsAny(query, const [
      'bikri',
      'sales',
      'sale',
      'revenue',
      'বিক্রি',
    ])) {
      return _salesAnswer(snapshot, query, isBangla);
    }
    if (_containsAny(query, const [
      'ki korbo',
      'suggestion',
      'advice',
      'plan',
      'poramorsho',
      'কি করবো',
      'পরামর্শ',
    ])) {
      return _adviceAnswer(snapshot, isBangla);
    }
    return null;
  }

  static VerifiedBusinessAnswer _salesAnswer(
    _BusinessSnapshot snapshot,
    String query,
    bool bn,
  ) {
    final period = _periodFor(query, snapshot.now);
    final sales = snapshot.salesIn(period);
    final amount = _sumSales(sales);
    if (sales.isEmpty) return _noRecords(period.label(bn), bn);
    final message = bn
        ? '${period.label(true)} রেকর্ড করা বিক্রি ${money(amount)}। মোট ${sales.length}টি বিক্রি হয়েছে।'
        : 'Recorded sales ${period.label(false).toLowerCase()} are ${money(amount)} from ${sales.length} sale(s).';
    return _verified(message, period.label(bn));
  }

  static VerifiedBusinessAnswer _profitAnswer(
    _BusinessSnapshot snapshot,
    String query,
    bool bn,
  ) {
    final period = _periodFor(query, snapshot.now);
    final sales = snapshot.salesIn(period);
    final profit = sales.fold<double>(0, (sum, sale) => sum + sale.profit);
    if (sales.isEmpty) return _noRecords(period.label(bn), bn);
    final message = bn
        ? '${period.label(true)} আনুমানিক মোট লাভ ${money(profit)}। এটি পণ্যের সংরক্ষিত ক্রয়মূল্য ও বিক্রয়মূল্য থেকে হিসাব করা হয়েছে; আলাদা খরচ এতে ধরা হয়নি।'
        : 'Estimated gross profit ${period.label(false).toLowerCase()} is ${money(profit)}. It uses recorded purchase and selling prices, before separate expenses.';
    return _verified(message, period.label(bn));
  }

  static VerifiedBusinessAnswer _expenseAnswer(
    _BusinessSnapshot snapshot,
    String query,
    bool bn,
  ) {
    final period = _periodFor(query, snapshot.now);
    final expenses = snapshot.expensesIn(period);
    final amount = expenses.fold<double>(
      0,
      (sum, expense) => sum + expense.amount,
    );
    if (expenses.isEmpty) return _noRecords(period.label(bn), bn);
    final largest = [...expenses]..sort((a, b) => b.amount.compareTo(a.amount));
    final detail = largest.first;
    final message = bn
        ? '${period.label(true)} রেকর্ড করা খরচ ${money(amount)}। সবচেয়ে বড় খরচ ছিল ${detail.categoryLabel.isEmpty ? detail.description : detail.categoryLabel} (${money(detail.amount)})।'
        : 'Recorded expenses ${period.label(false).toLowerCase()} are ${money(amount)}. The largest was ${detail.categoryLabel.isEmpty ? detail.description : detail.categoryLabel} (${money(detail.amount)}).';
    return _verified(message, period.label(bn));
  }

  static VerifiedBusinessAnswer _dueAnswer(
    _BusinessSnapshot snapshot,
    String query,
    bool bn,
  ) {
    final matchingCustomer = snapshot.customerMatching(query);
    if (matchingCustomer != null) {
      final due = snapshot.dueFor(matchingCustomer.customerId);
      final message = bn
          ? '${matchingCustomer.name}-এর বর্তমান পাওনা ${money(due)}।'
          : '${matchingCustomer.name} currently has ${money(due)} due.';
      return _verified(message, bn ? 'কাস্টমার হিসাব' : 'Customer ledger');
    }
    final debtors = snapshot.debtors;
    final totalDue = debtors.fold<double>(0, (sum, row) => sum + row.due);
    if (debtors.isEmpty || totalDue <= 0) {
      return _verified(
        bn
            ? 'এখন কোনো বকেয়া পাওনা রেকর্ডে নেই।'
            : 'There is no outstanding customer due in the records.',
        bn ? 'কাস্টমার হিসাব' : 'Customer ledger',
      );
    }
    final names = debtors
        .take(3)
        .map((row) => '${row.customer.name} (${money(row.due)})')
        .join(', ');
    final message = bn
        ? 'মোট পাওনা ${money(totalDue)}। সবচেয়ে বেশি বাকি আছে $names।'
        : 'Total receivable is ${money(totalDue)}. Highest dues: $names.';
    return _verified(message, bn ? 'কাস্টমার হিসাব' : 'Customer ledger');
  }

  static VerifiedBusinessAnswer _stockAnswer(
    _BusinessSnapshot snapshot,
    String query,
    bool bn,
  ) {
    final product = snapshot.productMatching(query);
    if (product != null) {
      final name = product.displayName(bn ? 'bn' : 'en');
      final expiry = product.expiryDate == null
          ? ''
          : bn
          ? ' মেয়াদ শেষের তারিখ ${_date(product.expiryDate!)}।'
          : ' Expiry date: ${_date(product.expiryDate!)}.';
      final message = bn
          ? '$name-এর বর্তমান স্টক ${product.stockQty} ${product.unit}। বিক্রয়মূল্য ${money(product.sellingPrice)}।$expiry'
          : '$name has ${product.stockQty} ${product.unit} in stock. Selling price: ${money(product.sellingPrice)}.$expiry';
      return _verified(message, bn ? 'পণ্যের স্টক' : 'Product stock');
    }
    final low =
        snapshot.products.where((product) => product.isLowStock).toList()
          ..sort((a, b) => a.stockQty.compareTo(b.stockQty));
    if (low.isEmpty) {
      return _verified(
        bn
            ? 'এখন কোনো পণ্য লো-স্টক সীমার নিচে নেই।'
            : 'No product is currently below its low-stock alert level.',
        bn ? 'পণ্যের স্টক' : 'Product stock',
      );
    }
    final names = low
        .take(5)
        .map(
          (product) =>
              '${product.displayName(bn ? 'bn' : 'en')} (${product.stockQty} ${product.unit})',
        )
        .join(', ');
    return _verified(
      bn
          ? '${low.length}টি পণ্যের স্টক কম। যেমন: $names।'
          : '${low.length} item(s) are low in stock: $names.',
      bn ? 'পণ্যের স্টক' : 'Product stock',
    );
  }

  static VerifiedBusinessAnswer _topProductAnswer(
    _BusinessSnapshot snapshot,
    bool bn,
  ) {
    if (snapshot.topProducts.isEmpty) {
      return _noRecords(bn ? 'গত ৩০ দিন' : 'the last 30 days', bn);
    }
    final top = snapshot.topProducts.first;
    final name = top.displayName(bn);
    final message = bn
        ? 'গত ৩০ দিনে সবচেয়ে বেশি বিক্রি হয়েছে $name: ${_number(top.quantity)} ${top.unit}, বিক্রির পরিমাণ ${money(top.sales)}।'
        : '$name is the top seller in the last 30 days: ${_number(top.quantity)} ${top.unit}, worth ${money(top.sales)}.';
    return _verified(message, bn ? 'গত ৩০ দিনের বিক্রি' : 'Last 30 days sales');
  }

  static VerifiedBusinessAnswer _adviceAnswer(
    _BusinessSnapshot snapshot,
    bool bn,
  ) {
    final low = snapshot.products.where((product) => product.isLowStock).length;
    final totalDue = snapshot.debtors.fold<double>(
      0,
      (sum, row) => sum + row.due,
    );
    if (totalDue > 0) {
      return _verified(
        bn
            ? 'আজ আগে ${snapshot.debtors.first.customer.name}-এর ${money(snapshot.debtors.first.due)} বকেয়া ফলো-আপ করুন। মোট পাওনা ${money(totalDue)}; একটি নিশ্চিত পেমেন্ট তারিখ নিলে ক্যাশ ফ্লো ভালো থাকবে।'
            : 'Start by following up ${snapshot.debtors.first.customer.name} for ${money(snapshot.debtors.first.due)}. Total receivable is ${money(totalDue)}, so a confirmed payment date can improve cash flow.',
        bn ? 'কাস্টমার হিসাব' : 'Customer ledger',
      );
    }
    if (low > 0) {
      return _verified(
        bn
            ? '$lowটি পণ্যের স্টক কম আছে। আজ বিক্রির গতি দেখে প্রয়োজনীয় পণ্যের ক্রয় তালিকা তৈরি করুন।'
            : '$low item(s) are low in stock. Review sales velocity and create a purchase list today.',
        bn ? 'পণ্যের স্টক' : 'Product stock',
      );
    }
    return _verified(
      bn
          ? 'আজকের বিক্রি ও খরচ ঠিকভাবে যোগ করুন। দিনের শেষে ক্যাশ মিলিয়ে নিলে পরের দিনের সিদ্ধান্ত আরও নির্ভরযোগ্য হবে।'
          : 'Record today\'s sales and expenses, then close and reconcile cash at day end for more reliable decisions tomorrow.',
      bn ? 'ব্যবসার রেকর্ড' : 'Business records',
    );
  }

  static VerifiedBusinessAnswer _noRecords(String period, bool bn) => _verified(
    bn
        ? '$period-এর কোনো রেকর্ড পাওয়া যায়নি।'
        : 'No records were found for $period.',
    bn ? 'ব্যবসার রেকর্ড' : 'Business records',
  );

  static VerifiedBusinessAnswer _verified(String answer, String source) =>
      VerifiedBusinessAnswer(answer: answer, source: source);

  static bool _containsAny(String input, List<String> terms) =>
      terms.any(input.contains);

  static String _normalise(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s\u0980-\u09ff]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static double _sumSales(Iterable<Sale> sales) =>
      sales.fold<double>(0, (sum, sale) => sum + sale.totalAmount);

  static String _number(double value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);

  static String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}-${value.month.toString().padLeft(2, '0')}-${value.year}';

  static _BusinessPeriod _periodFor(String query, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    if (_containsAny(query, const ['yesterday', 'gotokal', 'গতকাল'])) {
      return _BusinessPeriod(
        today.subtract(const Duration(days: 1)),
        today,
        _BusinessPeriodType.yesterday,
      );
    }
    if (_containsAny(query, const [
      '7 din',
      '7 day',
      'week',
      'sapta',
      'সপ্তাহ',
    ])) {
      return _BusinessPeriod(
        today.subtract(const Duration(days: 7)),
        today.add(const Duration(days: 1)),
        _BusinessPeriodType.lastSevenDays,
      );
    }
    if (_containsAny(query, const [
      '30 din',
      '30 day',
      'month',
      'mas',
      'মাস',
    ])) {
      return _BusinessPeriod(
        today.subtract(const Duration(days: 30)),
        today.add(const Duration(days: 1)),
        _BusinessPeriodType.lastThirtyDays,
      );
    }
    return _BusinessPeriod(
      today,
      today.add(const Duration(days: 1)),
      _BusinessPeriodType.today,
    );
  }
}

class VerifiedBusinessAnswer {
  const VerifiedBusinessAnswer({required this.answer, required this.source});

  final String answer;
  final String source;
}

class _BusinessSnapshot {
  _BusinessSnapshot({
    required this.now,
    required this.sales,
    required this.products,
    required this.customers,
    required this.payments,
    required this.ledger,
    required this.expenses,
  }) : debtors = _buildDebtors(sales, customers, payments, ledger),
       topProducts = _buildTopProducts(sales, products, now);

  final DateTime now;
  final List<Sale> sales;
  final List<Product> products;
  final List<Customer> customers;
  final List<Payment> payments;
  final List<CustomerLedgerEntry> ledger;
  final List<Expense> expenses;
  final List<_Debtor> debtors;
  final List<_TopProduct> topProducts;

  factory _BusinessSnapshot.fromDatabase(
    LocalDatabase db, {
    required String shopId,
    required DateTime now,
  }) => _BusinessSnapshot(
    now: now,
    sales: db.sales
        .valuesForShop(shopId)
        .where((item) => !item.isDeleted)
        .toList(),
    products: db.products
        .valuesForShop(shopId)
        .where((item) => !item.isDeleted)
        .toList(),
    customers: db.customers
        .valuesForShop(shopId)
        .where((item) => !item.isDeleted)
        .toList(),
    payments: db.payments
        .valuesForShop(shopId)
        .where((item) => !item.isDeleted)
        .toList(),
    ledger: db.customerLedgerEntries
        .valuesForShop(shopId)
        .where((item) => !item.isDeleted)
        .toList(),
    expenses: db.expenses
        .valuesForShop(shopId)
        .where((item) => !item.isDeleted)
        .toList(),
  );

  List<Sale> salesIn(_BusinessPeriod period) => sales
      .where(
        (sale) =>
            !sale.createdAt.isBefore(period.start) &&
            sale.createdAt.isBefore(period.end),
      )
      .toList();

  List<Expense> expensesIn(_BusinessPeriod period) => expenses
      .where(
        (expense) =>
            !expense.date.isBefore(period.start) &&
            expense.date.isBefore(period.end),
      )
      .toList();

  double dueFor(String customerId) {
    final saleDue = sales
        .where((sale) => sale.customerId == customerId)
        .fold<double>(0, (sum, sale) => sum + sale.dueAmount);
    final unlinkedPayments = payments
        .where(
          (payment) =>
              payment.customerId == customerId && payment.saleId == null,
        )
        .fold<double>(0, (sum, payment) => sum + payment.amount);
    final adjustments = ledger
        .where((entry) => entry.customerId == customerId)
        .fold<double>(0, (sum, entry) => sum + entry.signedAmount);
    return saleDue - unlinkedPayments + adjustments;
  }

  Customer? customerMatching(String query) {
    final matches = customers.where((customer) {
      final name = _normaliseCustomer(customer.name);
      return name.length >= 2 && query.contains(name);
    }).toList();
    return matches.isEmpty
        ? null
        : matches.reduce((a, b) => a.name.length >= b.name.length ? a : b);
  }

  Product? productMatching(String query) {
    final matches = products.where((product) {
      final en = _normaliseCustomer(product.nameEn);
      final bn = _normaliseCustomer(product.nameBn);
      return (en.length >= 2 && query.contains(en)) ||
          (bn.length >= 2 && query.contains(bn));
    }).toList();
    return matches.isEmpty
        ? null
        : matches.reduce((a, b) => a.nameEn.length >= b.nameEn.length ? a : b);
  }

  static String _normaliseCustomer(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s\u0980-\u09ff]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static List<_Debtor> _buildDebtors(
    List<Sale> sales,
    List<Customer> customers,
    List<Payment> payments,
    List<CustomerLedgerEntry> ledger,
  ) {
    final result = <_Debtor>[];
    for (final customer in customers) {
      final saleDue = sales
          .where((sale) => sale.customerId == customer.customerId)
          .fold<double>(0, (sum, sale) => sum + sale.dueAmount);
      final unlinkedPayments = payments
          .where(
            (payment) =>
                payment.customerId == customer.customerId &&
                payment.saleId == null,
          )
          .fold<double>(0, (sum, payment) => sum + payment.amount);
      final adjustments = ledger
          .where((entry) => entry.customerId == customer.customerId)
          .fold<double>(0, (sum, entry) => sum + entry.signedAmount);
      final due = saleDue - unlinkedPayments + adjustments;
      if (due > 0) result.add(_Debtor(customer, due));
    }
    result.sort((a, b) => b.due.compareTo(a.due));
    return result;
  }

  static List<_TopProduct> _buildTopProducts(
    List<Sale> sales,
    List<Product> products,
    DateTime now,
  ) {
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 30));
    final totals = <String, _TopProduct>{};
    for (final sale in sales.where((sale) => !sale.createdAt.isBefore(start))) {
      for (final item in sale.items) {
        final product = products
            .where((row) => row.productId == item.productId)
            .firstOrNull;
        final existing = totals[item.productId];
        totals[item.productId] = _TopProduct(
          nameEn: product?.displayName('en') ?? item.name,
          nameBn: product?.displayName('bn') ?? item.name,
          unit: product?.unit ?? 'pcs',
          quantity: (existing?.quantity ?? 0) + item.qty,
          sales: (existing?.sales ?? 0) + item.lineTotal,
        );
      }
    }
    final result = totals.values.toList()
      ..sort((a, b) => b.quantity.compareTo(a.quantity));
    return result;
  }
}

class _Debtor {
  const _Debtor(this.customer, this.due);

  final Customer customer;
  final double due;
}

class _TopProduct {
  const _TopProduct({
    required this.nameEn,
    required this.nameBn,
    required this.unit,
    required this.quantity,
    required this.sales,
  });

  final String nameEn;
  final String nameBn;
  final String unit;
  final double quantity;
  final double sales;

  String displayName(bool bangla) =>
      bangla && nameBn.isNotEmpty ? nameBn : nameEn;
}

enum _BusinessPeriodType { today, yesterday, lastSevenDays, lastThirtyDays }

class _BusinessPeriod {
  const _BusinessPeriod(this.start, this.end, this.type);

  final DateTime start;
  final DateTime end;
  final _BusinessPeriodType type;

  String label(bool bn) => switch ((type, bn)) {
    (_BusinessPeriodType.today, true) => 'আজ',
    (_BusinessPeriodType.yesterday, true) => 'গতকাল',
    (_BusinessPeriodType.lastSevenDays, true) => 'গত ৭ দিন',
    (_BusinessPeriodType.lastThirtyDays, true) => 'গত ৩০ দিন',
    (_BusinessPeriodType.today, false) => 'today',
    (_BusinessPeriodType.yesterday, false) => 'yesterday',
    (_BusinessPeriodType.lastSevenDays, false) => 'the last 7 days',
    (_BusinessPeriodType.lastThirtyDays, false) => 'the last 30 days',
  };
}
