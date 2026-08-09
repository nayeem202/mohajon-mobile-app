import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/app/app_providers.dart';
import '../models/shortcut_item.dart';

const _storageKey = 'selectedShortcuts';

List<String> _defaultShortcuts() {
  final rng = Random();
  final ids = ShortcutItem.all.map((s) => s.id).toList()..shuffle(rng);
  return ids.take(rng.nextBool() ? 5 : 6).toList();
}

final selectedShortcutsProvider = StateNotifierProvider<SelectedShortcutsNotifier, List<String>>((ref) {
  final db = ref.watch(localDatabaseProvider);
  final saved = db.settings.get(_storageKey);
  if (saved is List) {
    return SelectedShortcutsNotifier(saved.cast<String>());
  }
  final defaults = _defaultShortcuts();
  db.settings.put(_storageKey, defaults);
  return SelectedShortcutsNotifier(defaults);
});

class SelectedShortcutsNotifier extends StateNotifier<List<String>> {
  SelectedShortcutsNotifier(super.state);

  bool isSelected(String id) => state.contains(id);

  int get selectedCount => state.length;

  void toggle(String id) {
    if (state.contains(id)) {
      state = state.where((i) => i != id).toList();
    } else if (state.length < ShortcutItem.maxCount) {
      state = [...state, id];
    }
  }

  void updateOrder(List<String> ids) {
    state = ids;
  }

  void save(WidgetRef ref) {
    final db = ref.read(localDatabaseProvider);
    db.settings.put(_storageKey, state);
  }
}
