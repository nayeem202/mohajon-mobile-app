import 'dart:convert';

import 'package:flutter_riverpod/legacy.dart';
import 'package:hive/hive.dart';

import '../constants/app_constants.dart';

const _appLockKey = 'appLock';
const _appLockPinKey = 'appLockPin';
const _lockAttemptsKey = 'appLockFailedAttempts';
const _lockoutUntilKey = 'appLockLockoutUntil';
const _maxAttempts = 5;

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

  int get failedAttempts => ((_box.get(_lockAttemptsKey) as num?) ?? 0).toInt();

  DateTime? get lockoutUntil {
    final raw = _box.get(_lockoutUntilKey) as String?;
    if (raw == null || raw.isEmpty) return null;
    final until = DateTime.tryParse(raw);
    if (until == null || !until.isAfter(DateTime.now())) return null;
    return until;
  }

  bool get isLockedOut => lockoutUntil != null;

  Duration get lockoutRemaining {
    final until = lockoutUntil;
    if (until == null) return Duration.zero;
    return until.difference(DateTime.now());
  }

  bool verify(String pin) {
    if (isLockedOut) return false;
    final stored = _box.get(_appLockPinKey) as String?;
    if (stored == null || stored.isEmpty) return false;
    final ok = stored == _hashPin(pin);
    if (ok) {
      _box.put(_lockAttemptsKey, 0);
      _box.delete(_lockoutUntilKey);
      return true;
    }
    final attempts = failedAttempts + 1;
    _box.put(_lockAttemptsKey, attempts);
    if (attempts >= _maxAttempts) {
      // Escalating lockout: 30s after the 5th miss, 60s after the 10th, ...
      final seconds = 30 * (attempts ~/ _maxAttempts);
      _box.put(
        _lockoutUntilKey,
        DateTime.now()
            .add(Duration(seconds: seconds))
            .toIso8601String(),
      );
    }
    return false;
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