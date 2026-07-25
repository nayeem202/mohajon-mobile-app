import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hive/hive.dart';

import '../../../core/constants/app_constants.dart';
import '../models/staff_model.dart';

final staffListProvider =
    StateNotifierProvider<StaffListNotifier, List<StaffMember>>((ref) {
  return StaffListNotifier();
});

class StaffListNotifier extends StateNotifier<List<StaffMember>> {
  StaffListNotifier() : super([]) {
    _load();
  }

  Box<dynamic> get _box => Hive.box(HiveBoxes.settings);

  void _load() {
    final raw = _box.get('staff_list');
    if (raw is List) {
      state = raw
          .map((e) => StaffMember.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
  }

  void _save() {
    _box.put('staff_list', state.map((s) => s.toJson()).toList());
  }

  void add(StaffMember member) {
    state = [...state, member];
    _save();
  }

  void update(String id, StaffMember updates) {
    state = state.map((s) => s.id == id ? updates : s).toList();
    _save();
  }

  void delete(String id) {
    state = state.where((s) => s.id != id).toList();
    _save();
  }

  void toggleActive(String id) {
    state = state.map((s) {
      if (s.id == id) return s.copyWith(active: !s.active);
      return s;
    }).toList();
    _save();
  }
}
