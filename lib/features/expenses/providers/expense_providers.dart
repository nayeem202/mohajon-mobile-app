import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/syncable.dart';
import '../models/expense.dart';

final expenseCategoriesProvider = Provider<List<ExpenseCategory>>((ref) {
  return const [
    ExpenseCategory(
      id: 'rent',
      label: 'Rent',
      icon: Icons.home_work_outlined,
      color: Color(0xFF7C3AED),
    ),
    ExpenseCategory(
      id: 'electricity',
      label: 'Electricity',
      icon: Icons.bolt_outlined,
      color: Color(0xFFF59E0B),
    ),
    ExpenseCategory(
      id: 'salaries',
      label: 'Salaries',
      icon: Icons.badge_outlined,
      color: Color(0xFF0F766E),
    ),
    ExpenseCategory(
      id: 'transport',
      label: 'Transport',
      icon: Icons.directions_bus_outlined,
      color: Color(0xFF2563EB),
    ),
    ExpenseCategory(
      id: 'maintenance',
      label: 'Maintenance',
      icon: Icons.handyman_outlined,
      color: Color(0xFFDC2626),
    ),
    ExpenseCategory(
      id: 'misc',
      label: 'Miscellaneous',
      icon: Icons.sell_outlined,
      color: Color(0xFF64748B),
    ),
  ];
});

final expenseServiceProvider = Provider<ExpenseService>((ref) {
  return ExpenseService(ref, const Uuid());
});

final expensesProvider = StreamProvider<List<Expense>>((ref) {
  final shopId = ref.watch(shopIdProvider);
  return ref.watch(localDatabaseProvider).expenses.watchForShop(shopId);
});

final expenseMonthFilterProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

final expenseCategoryFilterProvider = StateProvider<String>((ref) => '');

final expenseMonthsProvider = Provider<List<DateTime>>((ref) {
  final expenses = ref.watch(expensesProvider).value ?? const <Expense>[];
  final monthMap = <int, DateTime>{};
  for (final expense in expenses) {
    final month = DateTime(expense.date.year, expense.date.month);
    monthMap[_monthKey(month)] = month;
  }
  final now = DateTime.now();
  monthMap.putIfAbsent(_monthKey(DateTime(now.year, now.month)),
      () => DateTime(now.year, now.month));
  final months = monthMap.values.toList()..sort((a, b) => b.compareTo(a));
  return months;
});

final filteredExpensesProvider = Provider<List<Expense>>((ref) {
  final expenses = ref.watch(expensesProvider).value ?? const <Expense>[];
  final selectedMonth = ref.watch(expenseMonthFilterProvider);
  final selectedCategory = ref.watch(expenseCategoryFilterProvider);

  var filtered = expenses.where((expense) {
    return _isSameMonth(expense.date, selectedMonth);
  }).toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  if (selectedCategory.isNotEmpty) {
    filtered = filtered.where((expense) => expense.categoryId == selectedCategory).toList();
  }

  return filtered;
});

final expenseDashboardProvider = Provider<ExpenseDashboardData>((ref) {
  final expenses = ref.watch(expensesProvider).value ?? const <Expense>[];
  final selectedMonth = ref.watch(expenseMonthFilterProvider);
  final selectedCategory = ref.watch(expenseCategoryFilterProvider);
  final categories = ref.watch(expenseCategoriesProvider);

  final monthExpenses = expenses.where((expense) {
    return _isSameMonth(expense.date, selectedMonth);
  }).toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  final previousMonth = DateTime(selectedMonth.year, selectedMonth.month - 1);
  final previousMonthTotal = expenses
      .where((expense) => _isSameMonth(expense.date, previousMonth))
      .fold<double>(0, (sum, expense) => sum + expense.amount);

  final selectedMonthTotal = monthExpenses.fold<double>(
    0,
    (sum, expense) => sum + expense.amount,
  );

  final filteredEntries = selectedCategory.isEmpty
      ? monthExpenses
      : monthExpenses
          .where((expense) => expense.categoryId == selectedCategory)
          .toList();

  final filteredTotal = filteredEntries.fold<double>(
    0,
    (sum, expense) => sum + expense.amount,
  );

  final breakdown = categories
      .map((category) {
        final amount = monthExpenses
            .where((expense) => expense.categoryId == category.id)
            .fold<double>(0, (sum, expense) => sum + expense.amount);
        return ExpenseCategoryBreakdown(
          category: category,
          amount: amount,
          percent: selectedMonthTotal > 0
              ? (amount / selectedMonthTotal) * 100
              : 0,
        );
      })
      .where((item) => item.amount > 0)
      .toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));

  final double comparisonPercent = previousMonthTotal == 0
      ? (selectedMonthTotal == 0 ? 0.0 : 100.0)
      : ((selectedMonthTotal - previousMonthTotal) / previousMonthTotal) * 100;

  return ExpenseDashboardData(
    selectedMonth: selectedMonth,
    previousMonth: previousMonth,
    monthEntries: monthExpenses,
    filteredEntries: filteredEntries,
    selectedMonthTotal: selectedMonthTotal,
    previousMonthTotal: previousMonthTotal,
    filteredTotal: filteredTotal,
    comparisonPercent: comparisonPercent,
    breakdown: breakdown,
    selectedCategoryId: selectedCategory,
  );
});

final expenseTotalProvider = Provider<double>((ref) {
  final expenses = ref.watch(expensesProvider).value ?? const <Expense>[];
  return expenses.fold<double>(0, (sum, expense) => sum + expense.amount);
});

class ExpenseService {
  ExpenseService(this._ref, this._uuid);

  final Ref _ref;
  final Uuid _uuid;

  Future<void> seedDemoExpenses() async {
    final db = _ref.read(localDatabaseProvider);
    final shopId = _ref.read(shopIdProvider);
    if (shopId != AppConstants.demoShopId) return;
    if (db.expenses.valuesForShop(shopId).isNotEmpty) return;

    final now = DateTime.now();
    final months = [
      DateTime(now.year, now.month),
      DateTime(now.year, now.month - 1),
    ];
    final entries = <Expense>[
      Expense(
        expenseId: _uuid.v4(),
        description: 'Shop rent for Bashundhara outlet',
        amount: 15000,
        categoryId: 'rent',
        categoryLabel: 'Rent',
        date: DateTime(months[0].year, months[0].month, 1),
        shopId: shopId,
        updatedAt: now,
      ),
      Expense(
        expenseId: _uuid.v4(),
        description: 'Monthly electricity bill',
        amount: 4200,
        categoryId: 'electricity',
        categoryLabel: 'Electricity',
        date: DateTime(months[0].year, months[0].month, 3),
        shopId: shopId,
        updatedAt: now,
      ),
      Expense(
        expenseId: _uuid.v4(),
        description: 'Staff salaries for two sales assistants',
        amount: 12000,
        categoryId: 'salaries',
        categoryLabel: 'Salaries',
        date: DateTime(months[0].year, months[0].month, 5),
        shopId: shopId,
        updatedAt: now,
      ),
      Expense(
        expenseId: _uuid.v4(),
        description: 'Local delivery and market transport',
        amount: 2500,
        categoryId: 'transport',
        categoryLabel: 'Transport',
        date: DateTime(months[0].year, months[0].month, 8),
        shopId: shopId,
        updatedAt: now,
      ),
      Expense(
        expenseId: _uuid.v4(),
        description: 'AC service and counter repair',
        amount: 3800,
        categoryId: 'maintenance',
        categoryLabel: 'Maintenance',
        date: DateTime(months[0].year, months[0].month, 12),
        shopId: shopId,
        updatedAt: now,
      ),
      Expense(
        expenseId: _uuid.v4(),
        description: 'Tea, internet top-up, and small office items',
        amount: 1800,
        categoryId: 'misc',
        categoryLabel: 'Miscellaneous',
        date: DateTime(months[0].year, months[0].month, 18),
        shopId: shopId,
        updatedAt: now,
      ),
      Expense(
        expenseId: _uuid.v4(),
        description: 'Shop rent for previous month',
        amount: 15000,
        categoryId: 'rent',
        categoryLabel: 'Rent',
        date: DateTime(months[1].year, months[1].month, 1),
        shopId: shopId,
        updatedAt: now,
      ),
      Expense(
        expenseId: _uuid.v4(),
        description: 'Electricity bill for previous month',
        amount: 3900,
        categoryId: 'electricity',
        categoryLabel: 'Electricity',
        date: DateTime(months[1].year, months[1].month, 4),
        shopId: shopId,
        updatedAt: now,
      ),
      Expense(
        expenseId: _uuid.v4(),
        description: 'Staff salaries for previous month',
        amount: 12000,
        categoryId: 'salaries',
        categoryLabel: 'Salaries',
        date: DateTime(months[1].year, months[1].month, 5),
        shopId: shopId,
        updatedAt: now,
      ),
      Expense(
        expenseId: _uuid.v4(),
        description: 'Courier and pickup transport',
        amount: 2600,
        categoryId: 'transport',
        categoryLabel: 'Transport',
        date: DateTime(months[1].year, months[1].month, 10),
        shopId: shopId,
        updatedAt: now,
      ),
      Expense(
        expenseId: _uuid.v4(),
        description: 'Counter light replacement and wiring',
        amount: 2500,
        categoryId: 'maintenance',
        categoryLabel: 'Maintenance',
        date: DateTime(months[1].year, months[1].month, 14),
        shopId: shopId,
        updatedAt: now,
      ),
      Expense(
        expenseId: _uuid.v4(),
        description: 'Plastic bags, notebook, and petty cash',
        amount: 1400,
        categoryId: 'misc',
        categoryLabel: 'Miscellaneous',
        date: DateTime(months[1].year, months[1].month, 20),
        shopId: shopId,
        updatedAt: now,
      ),
    ];

    for (final entry in entries) {
      await db.expenses.put(entry);
    }
  }

  Future<Expense> addExpense({
    required String description,
    required double amount,
    required String categoryId,
    required String categoryLabel,
    required DateTime date,
    String notes = '',
  }) async {
    final now = DateTime.now();
    final expense = Expense(
      expenseId: _uuid.v4(),
      description: description,
      amount: amount,
      categoryId: categoryId,
      categoryLabel: categoryLabel,
      date: date,
      notes: notes,
      shopId: _ref.read(shopIdProvider),
      updatedAt: now,
      syncStatus: SyncStatus.pending,
    );
    await _ref.read(localDatabaseProvider).expenses.put(expense);
    await _ref.read(syncStateProvider.notifier).syncIfOnline();
    return expense;
  }

  Future<Expense> updateExpense({
    required Expense existing,
    required String description,
    required double amount,
    required String categoryId,
    required String categoryLabel,
    required DateTime date,
    String notes = '',
  }) async {
    final updated = existing.copyWith(
      description: description,
      amount: amount,
      categoryId: categoryId,
      categoryLabel: categoryLabel,
      date: date,
      notes: notes,
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );
    await _ref.read(localDatabaseProvider).expenses.put(updated);
    await _ref.read(syncStateProvider.notifier).syncIfOnline();
    return updated;
  }

  Future<void> deleteExpense(String expenseId) async {
    final db = _ref.read(localDatabaseProvider);
    final shopId = _ref.read(shopIdProvider);
    final existing = db.expenses.getForShop(shopId, expenseId);
    if (existing == null) return;
    await db.expenses.put(
      existing.copyWith(
        isDeleted: true,
        updatedAt: DateTime.now(),
        syncStatus: SyncStatus.pending,
      ),
    );
    await _ref.read(syncStateProvider.notifier).syncIfOnline();
  }
}

class ExpenseCategory {
  const ExpenseCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String id;
  final String label;
  final IconData icon;
  final Color color;
}

class ExpenseDashboardData {
  const ExpenseDashboardData({
    required this.selectedMonth,
    required this.previousMonth,
    required this.monthEntries,
    required this.filteredEntries,
    required this.selectedMonthTotal,
    required this.previousMonthTotal,
    required this.filteredTotal,
    required this.comparisonPercent,
    required this.breakdown,
    required this.selectedCategoryId,
  });

  final DateTime selectedMonth;
  final DateTime previousMonth;
  final List<Expense> monthEntries;
  final List<Expense> filteredEntries;
  final double selectedMonthTotal;
  final double previousMonthTotal;
  final double filteredTotal;
  final double comparisonPercent;
  final List<ExpenseCategoryBreakdown> breakdown;
  final String selectedCategoryId;
}

class ExpenseCategoryBreakdown {
  const ExpenseCategoryBreakdown({
    required this.category,
    required this.amount,
    required this.percent,
  });

  final ExpenseCategory category;
  final double amount;
  final double percent;
}

bool _isSameMonth(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month;
}

int _monthKey(DateTime value) => value.year * 100 + value.month;

String formatMonth(DateTime value) {
  return DateFormat('MMMM yyyy').format(value);
}
