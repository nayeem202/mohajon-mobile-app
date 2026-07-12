import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/models/syncable.dart';
import '../models/investment_item.dart';

final investmentsProvider = StreamProvider<List<InvestmentItem>>((ref) {
  final shopId = ref.watch(shopIdProvider);
  return ref.watch(localDatabaseProvider).investments.watchForShop(shopId);
});

final investmentSearchQueryProvider = StateProvider.autoDispose<String>(
  (ref) => '',
);

final investmentCategoryFilterProvider = StateProvider<String>((ref) => '');

final investmentSortProvider = StateProvider<InvestmentSort>((ref) => InvestmentSort.newest);

enum InvestmentSort { newest, oldest, highestAmount, lowestAmount, highestRoi, alphabetical }

final filteredInvestmentsProvider = Provider<List<InvestmentItem>>((ref) {
  final investments = ref.watch(investmentsProvider).value ?? const <InvestmentItem>[];
  final query = ref.watch(investmentSearchQueryProvider).trim().toLowerCase();
  final category = ref.watch(investmentCategoryFilterProvider);
  final sort = ref.watch(investmentSortProvider);

  var filtered = investments;

  if (query.isNotEmpty) {
    filtered = filtered.where((inv) {
      return inv.title.toLowerCase().contains(query) ||
          inv.investorName.toLowerCase().contains(query) ||
          inv.category.toLowerCase().contains(query) ||
          inv.description.toLowerCase().contains(query);
    }).toList();
  }

  if (category.isNotEmpty) {
    filtered = filtered.where((inv) => inv.category == category).toList();
  }

  filtered = [...filtered]..sort((a, b) {
    return switch (sort) {
      InvestmentSort.newest => b.date.compareTo(a.date),
      InvestmentSort.oldest => a.date.compareTo(b.date),
      InvestmentSort.highestAmount => b.amount.compareTo(a.amount),
      InvestmentSort.lowestAmount => a.amount.compareTo(b.amount),
      InvestmentSort.highestRoi => b.roi.compareTo(a.roi),
      InvestmentSort.alphabetical => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    };
  });

  return filtered;
});

final investmentItemsOverviewProvider = Provider<InvestmentOverview>((ref) {
  final investments = ref.watch(investmentsProvider).value ?? const <InvestmentItem>[];
  final totalInvested = investments.fold<double>(0, (s, i) => s + i.amount);
  final totalReturned = investments.fold<double>(0, (s, i) => s + i.returnAmount);
  final totalOutstanding = investments.fold<double>(0, (s, i) => s + i.outstandingAmount);
  final totalRoi = totalInvested > 0 ? ((totalReturned - totalInvested) / totalInvested) * 100 : 0.0;

  final categoryTotals = <String, double>{};
  for (final inv in investments) {
    categoryTotals.update(inv.category, (v) => v + inv.amount, ifAbsent: () => inv.amount);
  }

  final monthlyInvestments = <int, double>{};
  for (final inv in investments) {
    final monthKey = inv.date.year * 100 + inv.date.month;
    monthlyInvestments.update(monthKey, (v) => v + inv.amount, ifAbsent: () => inv.amount);
  }

  return InvestmentOverview(
    totalInvested: totalInvested,
    totalReturned: totalReturned,
    totalOutstanding: totalOutstanding,
    totalRoi: totalRoi,
    totalInvestments: investments.length,
    categoryTotals: categoryTotals,
    monthlyInvestments: monthlyInvestments,
  );
});

final investmentItemServiceProvider = Provider<InvestmentService>((ref) {
  return InvestmentService(ref, const Uuid());
});

class InvestmentService {
  InvestmentService(this._ref, this._uuid);

  final Ref _ref;
  final Uuid _uuid;

  Future<InvestmentItem> save({
    String? investmentId,
    required String title,
    String description = '',
    required String category,
    String investorName = '',
    required double amount,
    double returnAmount = 0,
    double outstandingAmount = 0,
    String notes = '',
    String status = 'active',
    DateTime? date,
  }) async {
    final now = DateTime.now();
    final item = InvestmentItem(
      investmentId: investmentId ?? _uuid.v4(),
      title: title,
      description: description,
      category: category,
      investorName: investorName,
      amount: amount,
      returnAmount: returnAmount,
      outstandingAmount: outstandingAmount,
      notes: notes,
      status: status,
      date: date ?? now,
      createdAt: investmentId == null ? now : now,
      shopId: _ref.read(shopIdProvider),
      updatedAt: now,
      syncStatus: SyncStatus.pending,
    );
    await _ref.read(localDatabaseProvider).investments.put(item);
    await _ref.read(syncStateProvider.notifier).syncIfOnline();
    return item;
  }

  Future<void> delete(String investmentId) async {
    final db = _ref.read(localDatabaseProvider);
    final existing = db.investments.getForShop(_ref.read(shopIdProvider), investmentId);
    if (existing == null) return;
    final deleted = existing.copyWith(
      isDeleted: true,
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );
    await db.investments.put(deleted);
    await _ref.read(syncStateProvider.notifier).syncIfOnline();
  }
}

class InvestmentOverview {
  const InvestmentOverview({
    required this.totalInvested,
    required this.totalReturned,
    required this.totalOutstanding,
    required this.totalRoi,
    required this.totalInvestments,
    required this.categoryTotals,
    required this.monthlyInvestments,
  });

  final double totalInvested;
  final double totalReturned;
  final double totalOutstanding;
  final double totalRoi;
  final int totalInvestments;
  final Map<String, double> categoryTotals;
  final Map<int, double> monthlyInvestments;
}

const investmentCategories = [
  'Setup',
  'Equipment',
  'Technology',
  'Inventory',
  'Vehicle',
  'Marketing',
  'Other',
];
