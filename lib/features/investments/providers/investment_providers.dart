import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/sale.dart';
import '../../../core/models/shop_profile.dart';
import '../../customers/providers/customer_providers.dart';
import '../../investors/models/investor.dart';
import '../../investors/providers/investor_providers.dart';
import '../../settings/providers/shop_profile_providers.dart';
import '../models/investment.dart';
import '../models/investment_category.dart';
import '../models/investment_member.dart';
import '../models/payout.dart';
import 'investment_service.dart';

final investmentServiceProvider = Provider<InvestmentService>((ref) {
  return InvestmentService(ref);
});

final investmentsStreamProvider = StreamProvider<List<Investment>>((ref) {
  return ref.watch(investmentServiceProvider).watchInvestments();
});

final investmentCategoriesStreamProvider =
    StreamProvider<List<InvestmentCategory>>((ref) {
  return ref.watch(investmentServiceProvider).watchCategories();
});

class InvestmentSearchQuery extends Notifier<String> {
  @override
  String build() => '';
  void update(String value) => state = value;
}
final investmentSearchQueryProvider =
    NotifierProvider<InvestmentSearchQuery, String>(InvestmentSearchQuery.new);

class InvestmentCategoryFilter extends Notifier<String> {
  @override
  String build() => '';
  void update(String value) => state = value;
}
final investmentCategoryFilterProvider =
    NotifierProvider<InvestmentCategoryFilter, String>(
        InvestmentCategoryFilter.new);

enum InvestmentSort { newest, oldest, highestAmount, lowestAmount, highestRoi, alphabetical }

class InvestmentSortNotifier extends Notifier<InvestmentSort> {
  @override
  InvestmentSort build() => InvestmentSort.newest;
  void update(InvestmentSort value) => state = value;
}
final investmentSortProvider =
    NotifierProvider<InvestmentSortNotifier, InvestmentSort>(
        InvestmentSortNotifier.new);

final filteredInvestmentsProvider = Provider<List<Investment>>((ref) {
  final investments = ref.watch(investmentsStreamProvider).value ?? [];
  final query = ref.watch(investmentSearchQueryProvider).trim().toLowerCase();
  final categoryFilter = ref.watch(investmentCategoryFilterProvider);
  final sort = ref.watch(investmentSortProvider);

  var filtered = investments;

  if (query.isNotEmpty) {
    filtered = filtered.where((inv) {
      return inv.title.toLowerCase().contains(query) ||
          inv.categoryName.toLowerCase().contains(query) ||
          inv.description.toLowerCase().contains(query);
    }).toList();
  }

  if (categoryFilter.isNotEmpty) {
    filtered =
        filtered.where((inv) => inv.categoryId == categoryFilter).toList();
  }

  filtered = [...filtered]..sort((a, b) {
      final cmp = switch (sort) {
        InvestmentSort.newest => b.createdAt.compareTo(a.createdAt),
        InvestmentSort.oldest => a.createdAt.compareTo(b.createdAt),
        InvestmentSort.highestAmount =>
          b.totalInvestment.compareTo(a.totalInvestment),
        InvestmentSort.lowestAmount =>
          a.totalInvestment.compareTo(b.totalInvestment),
        InvestmentSort.highestRoi => b.roi.compareTo(a.roi),
        InvestmentSort.alphabetical =>
          a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      };
      return cmp;
    });

  return filtered;
});

final investmentDashboardProvider = Provider<InvestmentDashboardData>((ref) {
  final investments = ref.watch(investmentsStreamProvider).value ?? [];
  final totalInvested =
      investments.fold<double>(0, (s, i) => s + i.totalInvestment);
  final totalReturns =
      investments.fold<double>(0, (s, i) => s + i.totalPaid);
  final totalOutstanding =
      investments.fold<double>(0, (s, i) => s + i.outstanding);
  final totalProfit =
      investments.fold<double>(0, (s, i) => s + i.totalProfit);
  final roi = totalInvested > 0 ? (totalProfit / totalInvested) * 100 : 0.0;

  final categoryTotals = <String, double>{};
  final categoryNames = <String, String>{};
  for (final inv in investments) {
    categoryTotals.update(
        inv.categoryId, (v) => v + inv.totalInvestment,
        ifAbsent: () => inv.totalInvestment);
    categoryNames[inv.categoryId] = inv.categoryName;
  }

  return InvestmentDashboardData(
    totalInvested: totalInvested,
    totalReturns: totalReturns,
    totalOutstanding: totalOutstanding,
    totalProfit: totalProfit,
    roi: roi,
    totalInvestments: investments.length,
    categoryTotals: categoryTotals,
    categoryNames: categoryNames,
  );
});

final investmentMembersProvider =
    Provider.family<List<InvestmentMember>, String>((ref, investmentId) {
  final members = ref.watch(investmentMembersStreamProvider(investmentId)).value ??
      [];
  return members;
});

final investmentMembersStreamProvider =
    StreamProvider.family<List<InvestmentMember>, String>((ref, investmentId) {
  return ref.watch(investmentServiceProvider).watchMembers(investmentId);
});

final payoutsStreamProvider =
    StreamProvider.family<List<Payout>, String>((ref, investmentId) {
  return ref.watch(investmentServiceProvider).watchPayouts(investmentId);
});

final investorPayoutsStreamProvider =
    StreamProvider.family<List<Payout>, String>((ref, investorId) {
  return ref.watch(investmentServiceProvider).watchPayoutsByInvestor(investorId);
});

final memberInvestorProvider =
    Provider.family<Investor?, String>((ref, investorId) {
  final investors = ref.watch(investorsStreamProvider).value ?? [];
  try {
    return investors.firstWhere((i) => i.id == investorId);
  } catch (_) {
    return null;
  }
});

class InvestmentDashboardData {
  const InvestmentDashboardData({
    required this.totalInvested,
    required this.totalReturns,
    required this.totalOutstanding,
    required this.totalProfit,
    required this.roi,
    required this.totalInvestments,
    required this.categoryTotals,
    required this.categoryNames,
  });

  final double totalInvested;
  final double totalReturns;
  final double totalOutstanding;
  final double totalProfit;
  final double roi;
  final int totalInvestments;
  final Map<String, double> categoryTotals;
  final Map<String, String> categoryNames;
}

final investmentOverviewProvider = Provider<InvestmentOverview>((ref) {
  final shopProfile = ref.watch(shopProfileProvider).value;
  final sales = ref.watch(salesStreamProvider).value ?? const <Sale>[];

  final owners = shopProfile?.effectiveOwners ?? [];
  final totalInvestment = shopProfile?.totalInvestment ?? 0;

  final totalSales = sales.length;
  final grossProfit = sales.fold<double>(
    0,
    (sum, sale) => sum + (sale.profit > 0 ? sale.profit : 0),
  );
  final grossLoss = sales.fold<double>(
    0,
    (sum, sale) => sum + (sale.profit < 0 ? sale.profit.abs() : 0),
  );
  final netProfit = grossProfit - grossLoss;

  return InvestmentOverview(
    owners: owners,
    totalInvestment: totalInvestment,
    grossProfit: grossProfit,
    grossLoss: grossLoss,
    netProfit: netProfit,
    totalSales: totalSales,
  );
});

class InvestmentOverview {
  const InvestmentOverview({
    required this.owners,
    required this.totalInvestment,
    required this.grossProfit,
    required this.grossLoss,
    required this.netProfit,
    required this.totalSales,
  });

  final List<ShopOwner> owners;
  final double totalInvestment;
  final double grossProfit;
  final double grossLoss;
  final double netProfit;
  final int totalSales;
}
