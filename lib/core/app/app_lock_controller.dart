import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hive/hive.dart';

import '../constants/app_constants.dart';

const _appLockKey = 'appLock';
const _appLockPinKey = 'appLockPin';

final appLockProvider = StateNotifierProvider<AppLockController, AppLockState>(
  (ref) => AppLockController(),
);

class AppLockState {
  const AppLockState({required this.enabled, required this.unlocked});

  final bool enabled;
  final bool unlocked;
}

class AppLockController extends StateNotifier<AppLockState> {
  AppLockController() : super(_initial());

  static Box<dynamic> get _box => Hive.box(HiveBoxes.settings);

  static AppLockState _initial() {
    final enabled = _box.get(_appLockKey, defaultValue: false) as bool;
    return AppLockState(enabled: enabled, unlocked: !enabled);
  }

  bool get hasPin {
    final stored = _box.get(_appLockPinKey) as String?;
    return stored != null && stored.isNotEmpty;
  }

  bool verify(String pin) {
    final stored = _box.get(_appLockPinKey) as String?;
    if (stored == null || stored.isEmpty) return false;
    return stored == _hashPin(pin);
  }

  Future<void> enable({String? pin}) async {
    if (pin != null && pin.isNotEmpty) {
      await _box.put(_appLockPinKey, _hashPin(pin));
    }
    await _box.put(_appLockKey, true);
    state = const AppLockState(enabled: true, unlocked: true);
  }

  Future<void> disable() async {
    await _box.put(_appLockKey, false);
    state = const AppLockState(enabled: false, unlocked: true);
  }

  void lock() {
    if (!state.enabled || !state.unlocked) return;
    state = AppLockState(enabled: true, unlocked: false);
  }

  void unlock() {
    if (state.unlocked) return;
    state = AppLockState(enabled: state.enabled, unlocked: true);
  }

  static String _hashPin(String pin) {
    const key = [0x5A, 0x3C, 0x91, 0x27, 0x0F, 0xE6, 0xB4, 0x70];
    final units = pin.codeUnits;
    final bytes = List<int>.generate(units.length * 2, (i) {
      final c = units[i ~/ 2];
      final byte = i.isEven ? (c >> 8) : (c & 0xFF);
      return (byte ^ key[i % key.length] ^ (i & 0xFF)) & 0xFF;
    });
    return 'p1:${base64Encode(bytes)}';
  }
}