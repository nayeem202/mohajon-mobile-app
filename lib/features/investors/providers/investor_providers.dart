import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/investor.dart';
import 'investor_service.dart';

final investorServiceProvider = Provider<InvestorService>((ref) {
  return InvestorService(ref);
});

final investorsStreamProvider = StreamProvider<List<Investor>>((ref) {
  return ref.watch(investorServiceProvider).watchAll();
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
  final totalInvestment =
      investors.fold<double>(0, (s, i) => s + i.totalInvestment);
  final totalProfit = investors.fold<double>(0, (s, i) => s + i.totalProfit);
  final totalLoss = investors.fold<double>(0, (s, i) => s + i.totalLoss);
  final totalOutstanding =
      investors.fold<double>(0, (s, i) => s + i.outstanding);

  return InvestorsOverview(
    totalInvestors: investors.length,
    totalInvestment: totalInvestment,
    totalProfit: totalProfit,
    totalLoss: totalLoss,
    totalOutstanding: totalOutstanding,
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
