import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage for the auth JWT access/refresh tokens and session.
///
/// Hive's settings box is plaintext on disk; tokens must not live there.
/// [TokenStore] keeps a small in-memory cache for the synchronous reads the
/// HTTP layers need and mirrors every write/delete into the platform's
/// encrypted keychain (Android Keystore-backed, iOS Keychain).
class TokenStore {
  TokenStore._();

  static final FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  static final Map<String, String> _cache = {};
  static bool _loaded = false;

  /// Loads stored values once at startup, before any HTTP call is made.
  static Future<void> load() async {
    if (_loaded) return;
    try {
      // Some Android Keystore implementations can indefinitely stall after a
      // system update or a restored backup. Authentication is recoverable, so
      // never let encrypted-storage I/O keep the native launch screen open.
      final all = await _storage.readAll().timeout(const Duration(seconds: 5));
      _cache.addAll(all);
    } catch (_) {
      // Keystore unavailable (e.g. headless test) — fall back to an empty
      // session; callers sign in again.
    }
    _loaded = true;
  }

  static String? get(String key) => _cache[key];

  static Future<void> put(String key, String value) async {
    _cache[key] = value;
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      // Best effort — keep the in-memory copy so the session still works for
      // this process even if persistence into the keychain failed once.
    }
  }

  static Future<void> remove(String key) async {
    _cache.remove(key);
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }
}
