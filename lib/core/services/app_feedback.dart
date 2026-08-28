import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

/// Reads the user's Sound & Display preferences (stored in the `settings`
/// Hive box) and fires the matching haptic / audible feedback. This makes the
/// Settings toggles have a real, observable effect across the app.
class AppFeedback {
  AppFeedback._();

  static const String _boxName = 'settings';
  static final AudioPlayer _player = AudioPlayer();

  static bool get _hapticEnabled {
    try {
      return Hive.box(_boxName).get('hapticFeedback', defaultValue: true) as bool;
    } catch (_) {
      return true;
    }
  }

  static bool get _soundEnabled {
    try {
      return Hive.box(_boxName).get('soundEffects', defaultValue: true) as bool;
    } catch (_) {
      return true;
    }
  }

  /// A noticeable haptic bump plus a real click sound — for primary taps.
  static void tap() {
    if (_hapticEnabled) HapticFeedback.mediumImpact();
    if (_soundEnabled) _playClick();
  }

  /// Haptic only (navigation, selection).
  static void haptic() {
    if (_hapticEnabled) HapticFeedback.mediumImpact();
  }

  /// Audible click only.
  static void sound() {
    if (_soundEnabled) _playClick();
  }

  static Future<void> _playClick() async {
    try {
      await _player.setVolume(1.0);
      await _player.play(AssetSource('sounds/click.wav'));
      debugPrint('AppFeedback: click sound played');
    } catch (e, st) {
      debugPrint('AppFeedback: sound error -> $e\n$st');
      try {
        await SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }
}
