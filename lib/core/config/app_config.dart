import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Central configuration to switch between authentication backends.
///
/// To force one backend at build time:
///   flutter build apk --dart-define=USE_CUSTOM_AUTH=false
///   flutter run --dart-define=AUTH_BASE_URL=http://192.168.0.10:8080
///   flutter run --dart-define=HAALKHATA_BASE_URL=http://192.168.0.10:8081
class AppConfig {
  const AppConfig._();

  /// true → custom auth service (Spring Boot), false → Firebase Auth.
  static const bool useCustomAuth = bool.fromEnvironment(
    'USE_CUSTOM_AUTH',
    defaultValue: true,
  );

  static const String _authBaseUrlOverride = String.fromEnvironment(
    'AUTH_BASE_URL',
  );

  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'HAALKHATA_BASE_URL',
  );

  static const String firebaseConfigPath = 'lib/firebase_options.dart';

  /// Base URL of the custom auth service.
  static String get authBaseUrl {
    if (_authBaseUrlOverride.isNotEmpty) return _authBaseUrlOverride;
    if (!kIsWeb && Platform.isAndroid) {
      // Android emulator reaches the host machine via 10.0.2.2.
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }

  /// Base URL of the Haalkhata business service (sync, investments, files).
  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8081';
    }
    return 'http://localhost:8081';
  }

  static const Duration authTimeout = Duration(seconds: 25);
}
