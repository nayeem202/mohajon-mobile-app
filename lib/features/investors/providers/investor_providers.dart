import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/sale.dart';
import '../models/investor.dart';
import '../../customers/providers/customer_providers.dart';
import '../../expenses/providers/expense_providers.dart';
import 'investor_service.dart';

final investorServiceProvider = Provider<InvestorService>((ref) {
  return InvestorService(ref);
});

final investorsStreamProvider = StreamProvider<List<Investor>>((ref) {
  return ref.watch(investorServiceProvider).watchAll();
});

final businessProfitProvider = Provider<BusinessProfit>((ref) {
  final sales = ref.watch(salesStreamProvider).value ?? const <Sale>[];
  final expenses = ref.watch(expensesProvider).value ?? const [];
  final grossProfit = sales.fold<double>(
    0,
    (sum, sale) => sum + (sale.profit > 0 ? sale.profit : 0),
  );
  final grossLoss = sales.fold<double>(
    0,
    (sum, sale) => sum + (sale.profit < 0 ? sale.profit.abs() : 0),
  );
  final totalExpense = expenses.fold<double>(
    0,
    (sum, expense) => sum + expense.amount,
  );

  return BusinessProfit(
    grossProfit: grossProfit,
    grossLoss: grossLoss,
    totalExpense: totalExpense,
    netProfit: grossProfit - grossLoss - totalExpense,
  );
});

class InvestorSearchQuery extends Notifier<String> {
  @override
  String build() => '';
  void update(String value) => state = value;
}
final investorSearchQueryProvider =
    NotifierProvider<InvestorSearchQuery, String>(InvestorSearchQuery.new);

final filteredInvestorsProvider = Provider<List<Investor>>((ref) {
  final investors = ref.watch(investorsStreamProvider).value ?? [];
  final query = ref.watch(investorSearchQueryProvider).trim().toLowerCase();

  if (query.isEmpty) return investors;

  return investors.where((inv) {
    return inv.name.toLowerCase().contains(query) ||
        inv.phone.contains(query) ||
        inv.email.toLowerCase().contains(query);
  }).toList();
});

final investorsOverviewProvider = Provider<InvestorsOverview>((ref) {
  final investors = ref.watch(investorsStreamProvider).value ?? [];
  final businessProfit = ref.watch(businessProfitProvider);
  final totalInvestment =
      investors.fold<double>(0, (s, i) => s + i.totalInvestment);
  final totalProfit = businessProfit.netProfit > 0
      ? businessProfit.netProfit
      : 0.0;
  final totalLoss = businessProfit.netProfit < 0
      ? businessProfit.netProfit.abs()
      : 0.0;
  final totalOutstanding = investors.fold<double>(
    0,
    (sum, investor) =>
        sum + ref.read(investorFinancialsProvider(investor.id)).outstanding,
  );

  return InvestorsOverview(
    totalInvestors: investors.length,
    totalInvestment: totalInvestment,
    totalProfit: totalProfit,
    totalLoss: totalLoss,
    totalOutstanding: totalOutstanding,
  );
});

final investorFinancialsProvider =
    Provider.family<InvestorFinancials, String>((ref, investorId) {
  final investors = ref.watch(investorsStreamProvider).value ?? const [];
  final investor = investors.where((item) => item.id == investorId).firstOrNull;
  final businessProfit = ref.watch(businessProfitProvider);
  if (investor == null) return const InvestorFinancials.empty();

  final totalInvestment = investors.fold<double>(
    0,
    (sum, item) => sum + item.totalInvestment,
  );
  final share = totalInvestment > 0
      ? investor.totalInvestment / totalInvestment
      : 0.0;
  final profit = businessProfit.netProfit * share;
  // Preserve already-recorded payouts while replacing the old saved profit
  // with the live net-profit allocation.
  final paidAmount = investor.totalInvestment +
      investor.totalProfit -
      investor.outstanding;
  final outstanding = (investor.totalInvestment + profit - paidAmount)
      .clamp(0.0, double.infinity)
      .toDouble();

  return InvestorFinancials(
    investment: investor.totalInvestment,
    profit: profit,
    loss: profit < 0 ? profit.abs() : 0,
    outstanding: outstanding,
    investmentCount: investor.investmentCount,
  );
});

class InvestorsOverview {
  const InvestorsOverview({
    required this.totalInvestors,
    required this.totalInvestment,
    required this.totalProfit,
    required this.totalLoss,
    required this.totalOutstanding,
  });

  final int totalInvestors;
  final double totalInvestment;
  final double totalProfit;
  final double totalLoss;
  final double totalOutstanding;
}

class BusinessProfit {
  const BusinessProfit({
    required this.grossProfit,
    required this.grossLoss,
    required this.totalExpense,
    required this.netProfit,
  });

  final double grossProfit;
  final double grossLoss;
  final double totalExpense;
  final double netProfit;
}

class InvestorFinancials {
  const InvestorFinancials({
    required this.investment,
    required this.profit,
    required this.loss,
    required this.outstanding,
    required this.investmentCount,
  });

  const InvestorFinancials.empty()
      : investment = 0,
        profit = 0,
        loss = 0,
        outstanding = 0,
        investmentCount = 0;

  final double investment;
  final double profit;
  final double loss;
  final double outstanding;
  final int investmentCount;
}
