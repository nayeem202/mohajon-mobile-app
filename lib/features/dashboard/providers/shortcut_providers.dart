import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/app/app_providers.dart';
import '../../customers/presentation/customer_form_screen.dart';
import '../../customers/presentation/customer_list_screen.dart';
import '../../expenses/presentation/expenses_screen.dart';
import '../../investments/presentation/investment_dashboard_screen.dart';
import '../../investors/presentation/investor_list_screen.dart';
import '../../pos/presentation/pos_screen.dart';
import '../../pos/presentation/sales_history_screen.dart';
import '../../products/presentation/product_form_screen.dart';
import '../../products/presentation/product_list_screen.dart';
import '../../purchases/presentation/purchase_screen.dart';
import '../../reports/presentation/reports_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../staff/presentation/staff_list_screen.dart';
import '../../vendors/presentation/vendor_list_screen.dart';
import '../data/shortcut_repository.dart';
import '../presentation/models/shortcut_model.dart';

final shortcutRepositoryProvider = Provider<ShortcutRepository>((ref) {
  final db = ref.watch(localDatabaseProvider);
  return ShortcutRepository(db.settings);
});

final selectedShortcutIdsProvider =
    StateNotifierProvider<ShortcutIdsNotifier, List<String>>((ref) {
  final repo = ref.watch(shortcutRepositoryProvider);
  return ShortcutIdsNotifier(repo);
});

class ShortcutIdsNotifier extends StateNotifier<List<String>> {
  final ShortcutRepository _repo;

  ShortcutIdsNotifier(this._repo) : super(_repo.load());

  void toggle(String id) {
    if (state.contains(id)) {
      state = [...state.where((x) => x != id)];
    } else {
      if (state.length >= 8) return;
      state = [...state, id];
    }
    _repo.save(state);
  }

  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final list = [...state];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = list;
    _repo.save(state);
  }

  void replace(List<String> ids) {
    state = ids;
    _repo.save(state);
  }
}

final selectedShortcutsProvider = Provider<List<ShortcutItem>>((ref) {
  final all = allShortcutItems;
  final ids = ref.watch(selectedShortcutIdsProvider);
  final map = {for (final s in all) s.id: s};
  return [
    for (final id in ids)
      if (map.containsKey(id)) map[id]!,
  ];
});

void navigateToShortcut(BuildContext context, ShortcutItem item) {
  Widget screen;
  switch (item.action) {
    case ShortcutAction.newSale:
    case ShortcutAction.pos:
      screen = const PosScreen();
    case ShortcutAction.addProduct:
      screen = const ProductFormScreen();
    case ShortcutAction.addClient:
      screen = const CustomerFormScreen();
    case ShortcutAction.stock:
      screen = const ProductListScreen();
    case ShortcutAction.clients:
      screen = const CustomerListScreen();
    case ShortcutAction.expenses:
      screen = const ExpensesScreen();
    case ShortcutAction.vendors:
      screen = const VendorListScreen();
    case ShortcutAction.investors:
      screen = const InvestorListScreen();
    case ShortcutAction.reports:
      screen = const ReportsScreen();
    case ShortcutAction.staff:
      screen = const StaffListScreen();
    case ShortcutAction.settings:
      screen = const SettingsScreen();
    case ShortcutAction.purchase:
      screen = const PurchaseScreen();
    case ShortcutAction.salesHistory:
      screen = const SalesHistoryScreen();
    case ShortcutAction.investments:
      screen = const InvestmentDashboardScreen();
  }
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}