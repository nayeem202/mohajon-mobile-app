import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/models/sale.dart';
import '../../../core/models/shop_profile.dart';
import '../../customers/providers/customer_providers.dart';
import '../../expenses/providers/expense_providers.dart';
import '../../investors/models/investor.dart';
import '../../investors/providers/investor_providers.dart';
import '../../settings/providers/shop_profile_providers.dart';
import '../../notifications/models/notification_model.dart';
import '../../notifications/providers/notification_providers.dart';
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

final _profitSyncSignatureProvider = StateProvider<String>((ref) => '');

/// Keeps backend investment profit allocation current even when the investor
/// screen is not open.
final investmentProfitSyncProvider = Provider<void>((ref) {
  final investments = ref.watch(investmentsStreamProvider).value;
  final netProfit = ref.watch(businessProfitProvider).netProfit;
  if (investments == null || investments.isEmpty) return;
  final totalInvestment = investments.fold<double>(
    0,
    (sum, investment) => sum + investment.totalInvestment,
  );
  if (totalInvestment <= 0) return;
  final composition = investments
      .map((investment) =>
          '${investment.id}:${investment.totalInvestment.toStringAsFixed(2)}')
      .join('|');
  final signature = '${netProfit.toStringAsFixed(2)}:$totalInvestment:$composition';
  if (ref.read(_profitSyncSignatureProvider) == signature) return;
  ref.read(_profitSyncSignatureProvider.notifier).state = signature;
  Future<void>(() async {
    final service = ref.read(investmentServiceProvider);
    for (final investment in investments) {
      final share = investment.totalInvestment / totalInvestment;
      await service.updateInvestmentProfit(
        investmentId: investment.id,
        totalProfit: netProfit * share,
      );
    }
    ref.read(notificationServiceProvider).add(
          type: NotificationType.investment,
          title: netProfit < 0 ? 'Investor loss updated' : 'Investor profit updated',
          message: netProfit < 0
              ? 'Current business loss allocation: ৳${netProfit.abs().toStringAsFixed(2)}.'
              : 'Current net profit pool: ৳${netProfit.toStringAsFixed(2)}.',
          category: NotificationCategory.platform,
          sourceKey: 'investment-profit:$signature',
        );
  }).catchError((_) {
    ref.read(_profitSyncSignatureProvider.notifier).state = '';
  });
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
  final totalExpense = ref.watch(expensesProvider).value?.fold<double>(
            0,
            (sum, expense) => sum + expense.amount,
          ) ??
      0;
  final netProfit = grossProfit - grossLoss - totalExpense;

  return InvestmentOverview(
    owners: owners,
    totalInvestment: totalInvestment,
    grossProfit: grossProfit,
    grossLoss: grossLoss,
    netProfit: netProfit,
    totalExpense: totalExpense,
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
    required this.totalExpense,
    required this.totalSales,
  });

  final List<ShopOwner> owners;
  final double totalInvestment;
  final double grossProfit;
  final double grossLoss;
  final double netProfit;
  final double totalExpense;
  final int totalSales;
}
