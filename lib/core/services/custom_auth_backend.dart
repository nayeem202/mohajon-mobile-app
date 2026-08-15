import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

import '../app/app_providers.dart';
import '../config/app_config.dart';
import 'auth_backend.dart';
import 'device_session_service.dart';
import 'secure_http.dart';

/// Google Sign-In instance used by the custom auth backend.
final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  return GoogleSignIn.instance;
});

/// AuthBackend backed by the custom Spring Boot auth service.
///
/// Stores JWT access/refresh tokens and the session in the local Hive
/// settings box. Automatically refreshes the access token when a request
/// fails with 401 and retries it once.
class CustomAuthBackend implements AuthBackend {
  CustomAuthBackend(this._ref);

  final Ref _ref;
  final _deviceSessionService = DeviceSessionService();
  final _sessionController = StreamController<AuthSession?>.broadcast();
  Future<void>? _googleInitialization;

  static const _googleServerClientId =
      '273885941339-5eigr18p3tp5lt8h5ait4k2ae5oi6lbl.apps.googleusercontent.com';

  static const _kAccessToken = 'auth_access_token';
  static const _kRefreshToken = 'auth_refresh_token';
  static const _kSession = 'auth_session';

  Box<dynamic> get _settings => _ref.read(localDatabaseProvider).settings;

  String get _baseUrl => AppConfig.authBaseUrl;

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  @override
  bool get isReady => true;

  AuthSession? _sessionFromHive() {
    final raw = _settings.get(_kSession);
    if (raw is! Map) return null;
    return AuthSession(
      userId: (raw['userId'] ?? '') as String,
      email: (raw['email'] ?? '') as String,
      displayName: (raw['displayName'] ?? '') as String,
      phone: (raw['phone'] ?? '') as String,
      photoUrl: (raw['photoUrl'] ?? '') as String,
      emailVerified: (raw['emailVerified'] ?? false) as bool,
      isNewUser: (raw['isNewUser'] ?? false) as bool,
      provider: (raw['provider'] ?? 'local') as String,
      roles:
          (raw['roles'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
    );
  }

  @override
  Future<AuthSession?> currentSession() async {
    final access = _settings.get(_kAccessToken);
    if (access == null) return null;
    return _sessionFromHive();
  }

  @override
  Stream<AuthSession?> get sessionChanges => _sessionController.stream;

  @override
  Future<AuthSession> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
    Map<String, String> metadata = const {},
  }) async {
    await _post('/api/v1/auth/register', {
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'phone': phone.trim(),
      'password': password,
    });
    return _sessionFromHive() ?? _anonymousPreview(name, email, phone);
  }

  AuthSession _anonymousPreview(String name, String email, String phone) {
    return AuthSession(
      userId: '',
      email: email.trim().toLowerCase(),
      displayName: name.trim(),
      phone: phone.trim(),
      photoUrl: '',
      emailVerified: false,
      isNewUser: true,
    );
  }

  @override
  Future<void> sendEmailVerificationCode(String email) async {
    await _post('/api/v1/auth/resend-verification', {
      'email': email.trim().toLowerCase(),
    });
  }

  @override
  Future<void> verifyEmail({
    required String email,
    required String code,
  }) async {
    await _post('/api/v1/auth/verify-email', {
      'email': email.trim().toLowerCase(),
      'code': code.trim(),
    });
  }

  @override
  Future<AuthSession> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final session = await _deviceSessionService.currentSession();
    final response = await _post('/api/v1/auth/login', {
      'email': email.trim().toLowerCase(),
      'password': password,
      'deviceId': session.sessionId,
      'deviceName': session.deviceName,
    });
    return _handleTokenResponse(response);
  }

  @override
  Future<AuthSession> signInWithGoogle() async {
    final googleSignIn = _ref.read(googleSignInProvider);
    try {
      // google_sign_in 7.x requires explicit initialization before the
      // interactive authenticate call. Without this, Android throws a
      // configuration exception before the request reaches auth-service.
      _googleInitialization ??= googleSignIn.initialize(
        serverClientId: _googleServerClientId,
      );
      await _googleInitialization;

      final googleUser = await googleSignIn.authenticate();
      final idToken = googleUser.authentication.idToken;
      if (idToken == null) {
        throw const AuthException(
          'Gmail sign-in did not return an ID token. Please try again.',
        );
      }
      final session = await _deviceSessionService.currentSession();
      final response = await _post('/api/v1/auth/google', {
        'idToken': idToken,
        'deviceId': session.sessionId,
        'deviceName': session.deviceName,
      });
      return _handleTokenResponse(response);
    } on GoogleSignInException catch (error) {
      throw AuthException(
        'Google sign-in failed: ${error.description ?? error.code.name}',
        code: error.code.name,
      );
    }
  }

  @override
  Future<void> sendOtp({
    required String phone,
    required void Function(String verificationId) onCodeSent,
    required void Function(String message) onError,
  }) async {
    try {
      await _post('/api/v1/auth/send-otp', {'phone': phone.trim()});
      // The server looks the phone up by itself; the phone is the
      // verification id in this backend.
      onCodeSent(phone.trim());
    } catch (error) {
      onError(error is AuthException ? error.message : error.toString());
    }
  }

  @override
  Future<AuthSession> verifyOtp({
    required String verificationId,
    required String smsCode,
    required String phone,
  }) async {
    final session = await _deviceSessionService.currentSession();
    final response = await _post('/api/v1/auth/verify-otp', {
      'phone': phone.trim(),
      'code': smsCode.trim(),
      'deviceId': session.sessionId,
      'deviceName': session.deviceName,
    });
    return _handleTokenResponse(response);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _post('/api/v1/auth/forgot-password', {
      'email': email.trim().toLowerCase(),
    });
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _post('/api/v1/auth/change-password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    }, authenticated: true);
  }

  @override
  Future<void> setPasswordForGoogleAccount(String newPassword) async {
    throw const AuthException(
      'Setting a password for Gmail accounts is not supported yet. '
      'Sign in with Gmail instead.',
    );
  }

  @override
  Future<String> resolveShopId(AuthSession session) async {
    return 'shop_${session.userId}';
  }

  @override
  Future<void> signOut() async {
    final refreshToken = _settings.get(_kRefreshToken) as String?;
    try {
      if (refreshToken != null) {
        await _post('/api/v1/auth/logout', {'refreshToken': refreshToken});
      }
    } catch (_) {
      // Best-effort revocation; local sign-out proceeds regardless.
    }
    await _clearTokens();
    _sessionController.add(null);
  }

  // ---------------------------------------------------------------------
  // HTTP helpers
  // ---------------------------------------------------------------------

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    bool authenticated = false,
  }) async {
    final client = await secureHttpClient();
    return _request(
      () => client.post(
        _uri(path),
        headers: {
          'Content-Type': 'application/json',
          if (authenticated)
            'Authorization': 'Bearer ${_settings.get(_kAccessToken)}',
        },
        body: jsonEncode(body),
      ),
      path: path,
      body: body,
    );
  }

  Future<Map<String, dynamic>> _request(
    Future<http.Response> Function() send, {
    required String path,
    Map<String, dynamic>? body,
  }) async {
    final response = await send().timeout(AppConfig.authTimeout);
    if (response.statusCode == 401 && _settings.get(_kRefreshToken) != null) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final retry = await send().timeout(AppConfig.authTimeout);
        return _decode(retry, path);
      }
    }
    return _decode(response, path);
  }

  Future<bool> _tryRefresh() async {
    final refreshToken = _settings.get(_kRefreshToken) as String?;
    if (refreshToken == null) return false;
    try {
      final client = await secureHttpClient();
      final response = await client
          .post(
            _uri('/api/v1/auth/refresh'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(AppConfig.authTimeout);
      if (response.statusCode != 200) {
        await _clearTokens();
        _sessionController.add(null);
        return false;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await _saveTokens(data);
      return true;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _decode(http.Response response, String path) {
    Map<String, dynamic>? data;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) data = decoded;
    } catch (_) {
      // Non-JSON body (e.g. empty 204).
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data ?? const <String, dynamic>{};
    }
    final code = (data?['code'] ?? '').toString();
    final message =
        (data?['message'] ?? 'Something went wrong. Please try again.')
            .toString();
    throw AuthException(message, code: code);
  }

  Future<AuthSession> _handleTokenResponse(Map<String, dynamic> data) async {
    await _saveTokens(data);
    final session = _sessionFromHive();
    if (session == null) {
      throw const AuthException('We could not sign you in. Please try again.');
    }
    return session;
  }

  Future<void> _saveTokens(Map<String, dynamic> data) async {
    final access = (data['accessToken'] ?? '') as String;
    final refresh = (data['refreshToken'] ?? '') as String;
    await _settings.put(_kAccessToken, access);
    await _settings.put(_kRefreshToken, refresh);
    final user = data['user'];
    if (user is Map<String, dynamic>) {
      await _settings.put(_kSession, {
        'userId': (user['userId'] ?? '') as String,
        'email': (user['email'] ?? '') as String,
        'displayName': (user['displayName'] ?? '') as String,
        'phone': (user['phoneNumber'] ?? '') as String,
        'photoUrl': (user['photoUrl'] ?? '') as String,
        'emailVerified': (user['emailVerified'] ?? false) as bool,
        'isNewUser': (user['isNewUser'] ?? false) as bool,
        'provider': (user['provider'] ?? 'local') as String,
        'roles':
            (user['roles'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
      });
    }
    _sessionController.add(_sessionFromHive());
  }

  Future<void> _clearTokens() async {
    await _settings.delete(_kAccessToken);
    await _settings.delete(_kRefreshToken);
    await _settings.delete(_kSession);
  }
}
