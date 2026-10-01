import '../../../core/models/customer.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/product.dart';
import '../../../core/models/sale.dart';
import '../../expenses/models/expense.dart';

enum CoachInsightType { profitLeak, deadStock, riskyCustomer, unusualExpense }

class CoachInsight {
  const CoachInsight({
    required this.type,
    required this.priority,
    required this.titleEn,
    required this.titleBn,
    required this.bodyEn,
    required this.bodyBn,
    required this.actionEn,
    required this.actionBn,
    this.amount,
  });

  final CoachInsightType type;
  final int priority;
  final String titleEn;
  final String titleBn;
  final String bodyEn;
  final String bodyBn;
  final String actionEn;
  final String actionBn;
  final double? amount;
}

class BusinessCoachService {
  List<CoachInsight> generate({
    required List<Sale> sales,
    required List<Product> products,
    required List<Customer> customers,
    required List<Payment> payments,
    required List<Expense> expenses,
  }) {
    final insights = <CoachInsight>[];
    insights.addAll(_profitLeaks(sales));
    insights.addAll(_deadStock(sales, products));
    insights.addAll(_riskyCustomers(sales, customers, payments));
    insights.addAll(_unusualExpenses(expenses));
    insights.sort((a, b) => b.priority.compareTo(a.priority));
    return insights.take(8).toList();
  }

  List<CoachInsight> _profitLeaks(List<Sale> sales) {
    final lossByProduct = <String, double>{};
    for (final sale in sales.where((item) => !item.isDeleted)) {
      for (final item in sale.items) {
        final margin = item.unitPrice - item.purchasePrice;
        if (margin < 0) {
          lossByProduct[item.name] =
              (lossByProduct[item.name] ?? 0) + margin.abs() * item.qty;
        }
      }
    }
    if (lossByProduct.isEmpty) return const [];
    final top = lossByProduct.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return [
      CoachInsight(
        type: CoachInsightType.profitLeak,
        priority: 100,
        titleEn: 'Margin leak detected',
        titleBn: 'লাভ কমে যাচ্ছে',
        bodyEn: '${top.key} is selling below its purchase cost. Estimated loss: ${_money(top.value)}.',
        bodyBn: '${top.key} ক্রয়মূল্যের চেয়ে কমে বিক্রি হচ্ছে। আনুমানিক ক্ষতি ${_money(top.value)}।',
        actionEn: 'Review selling price',
        actionBn: 'বিক্রয়মূল্য যাচাই করুন',
        amount: top.value,
      ),
    ];
  }

  List<CoachInsight> _deadStock(List<Sale> sales, List<Product> products) {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final soldIds = <String>{};
    for (final sale in sales.where((item) => item.createdAt.isAfter(cutoff))) {
      soldIds.addAll(sale.items.map((item) => item.productId));
    }
    final dead = products
        .where((product) => !product.isDeleted && product.stockQty > 0 && !soldIds.contains(product.productId))
        .toList()
      ..sort((a, b) => b.stockQty.compareTo(a.stockQty));
    if (dead.isEmpty) return const [];
    final product = dead.first;
    return [
      CoachInsight(
        type: CoachInsightType.deadStock,
        priority: 80,
        titleEn: 'Dead stock needs attention',
        titleBn: 'অচল স্টক পড়ে আছে',
        bodyEn: '${product.nameEn} has ${product.stockQty} units with no sale in 30 days.',
        bodyBn: '${product.nameEn}-এর ${product.stockQty} ইউনিট ৩০ দিনে বিক্রি হয়নি।',
        actionEn: 'Create a clearance offer',
        actionBn: 'ছাড়ের অফার দিন',
      ),
    ];
  }

  List<CoachInsight> _riskyCustomers(
    List<Sale> sales,
    List<Customer> customers,
    List<Payment> payments,
  ) {
    final result = <CoachInsight>[];
    for (final customer in customers) {
      final customerSales = sales.where((sale) => sale.customerId == customer.customerId).toList();
      final due = customerSales.fold<double>(0, (sum, sale) => sum + sale.dueAmount) -
          payments.where((payment) => payment.customerId == customer.customerId && payment.saleId == null)
              .fold<double>(0, (sum, payment) => sum + payment.amount);
      if (due <= 0) continue;
      final oldestDue = customerSales
          .where((sale) => sale.dueAmount > 0)
          .map((sale) => sale.createdAt)
          .fold<DateTime?>(null, (oldest, date) => oldest == null || date.isBefore(oldest) ? date : oldest);
      final days = oldestDue == null ? 0 : DateTime.now().difference(oldestDue).inDays;
      if (days < 14 && due < 5000) continue;
      result.add(
        CoachInsight(
          type: CoachInsightType.riskyCustomer,
          priority: days >= 30 ? 90 : 70,
          titleEn: 'Customer due is at risk',
          titleBn: 'কাস্টমারের বাকি ঝুঁকিতে',
          bodyEn: '${customer.name} owes ${_money(due)} for $days days. Follow up today.',
          bodyBn: '${customer.name}-এর ${_money(due)} বাকি আছে $days দিন ধরে। আজ যোগাযোগ করুন।',
          actionEn: 'Send a polite reminder',
          actionBn: 'ভদ্রভাবে রিমাইন্ডার পাঠান',
          amount: due,
        ),
      );
    }
    return result;
  }

  List<CoachInsight> _unusualExpenses(List<Expense> expenses) {
    final now = DateTime.now();
    final currentMonth = expenses.where((expense) =>
        expense.date.year == now.year && expense.date.month == now.month);
    final currentByCategory = <String, double>{};
    for (final expense in currentMonth) {
      currentByCategory[expense.categoryLabel] =
          (currentByCategory[expense.categoryLabel] ?? 0) + expense.amount;
    }
    final previous = expenses.where((expense) {
      final month = DateTime(now.year, now.month - 1);
      return expense.date.year == month.year && expense.date.month == month.month;
    });
    final previousByCategory = <String, double>{};
    for (final expense in previous) {
      previousByCategory[expense.categoryLabel] =
          (previousByCategory[expense.categoryLabel] ?? 0) + expense.amount;
    }
    for (final entry in currentByCategory.entries) {
      final previousAmount = previousByCategory[entry.key] ?? 0;
      if (entry.value < 1000 || (previousAmount > 0 && entry.value < previousAmount * 1.5)) continue;
      return [
        CoachInsight(
          type: CoachInsightType.unusualExpense,
          priority: 60,
          titleEn: 'Unusual expense increase',
          titleBn: 'অস্বাভাবিক খরচ বেড়েছে',
          bodyEn: '${entry.key} is already ${_money(entry.value)} this month, higher than last month.',
          bodyBn: '${entry.key} খরচ এই মাসে ${_money(entry.value)}, গত মাসের চেয়ে বেশি।',
          actionEn: 'Review this expense category',
          actionBn: 'এই খরচের খাত যাচাই করুন',
          amount: entry.value,
        ),
      ];
    }
    return const [];
  }

  String _money(double value) => '৳${value.toStringAsFixed(0)}';
}

final businessCoachService = BusinessCoachService();
