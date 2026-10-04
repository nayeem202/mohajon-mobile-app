import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart'
    show debugPrint, debugPrintStack, kIsWeb;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

import '../app/app_providers.dart';
import '../config/app_config.dart';
import 'api_client.dart';
import 'auth_backend.dart';
import 'device_session_service.dart';
import 'secure_http.dart';
import 'secure_tokens.dart';

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
  CustomAuthBackend(this._ref) {
    // When the API client wipes the session (refresh token definitively
    // rejected), broadcast it so the app routes back to the login screen.
    ApiClient.onSessionInvalidated = () => _sessionController.add(null);
  }

  final Ref _ref;
  final _deviceSessionService = DeviceSessionService();
  final _sessionController = StreamController<AuthSession?>.broadcast();
  Future<void>? _googleInitialization;

  static const _googleServerClientId =
      '273885941339-5eigr18p3tp5lt8h5ait4k2ae5oi6lbl.apps.googleusercontent.com';

  /// Facebook App ID from the Meta developer console (Settings > Basic), passed
  /// in at build time with `--dart-define=FACEBOOK_APP_ID=...`.
  ///
  /// Left blank, Facebook sign-in reports that it is not configured instead of
  /// letting the native SDK fail with an error the user cannot act on. The same
  /// value has to reach the Android manifest for the native SDK to initialise,
  /// so it is declared in one place here and mirrored in
  /// `android/app/src/main/AndroidManifest.xml`.
  static const _facebookAppId = String.fromEnvironment('FACEBOOK_APP_ID');

  static const _kAccessToken = 'auth_access_token';
  static const _kRefreshToken = 'auth_refresh_token';
  static const _kSession = 'auth_session';

  Box<dynamic> get _settings => _ref.read(localDatabaseProvider).settings;

  String get _baseUrl => AppConfig.authBaseUrl;

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  @override
  bool get isReady => true;

  AuthSession? _sessionFromHive() {
    final raw = TokenStore.get(_kSession);
    if (raw == null) return null;
    Map<String, dynamic> decoded;
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! Map<String, dynamic>) return null;
      decoded = parsed;
    } catch (_) {
      return null;
    }
    return AuthSession(
      userId: (decoded['userId'] ?? '') as String,
      email: (decoded['email'] ?? '') as String,
      displayName: (decoded['displayName'] ?? '') as String,
      phone: (decoded['phone'] ?? '') as String,
      photoUrl: (decoded['photoUrl'] ?? '') as String,
      emailVerified: (decoded['emailVerified'] ?? false) as bool,
      isNewUser: (decoded['isNewUser'] ?? false) as bool,
      provider: (decoded['provider'] ?? 'local') as String,
      roles:
          (decoded['roles'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
    );
  }

  @override
  Future<AuthSession?> currentSession() async {
    final access = TokenStore.get(_kAccessToken);
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
    debugPrint('AUTH: signInWithEmail started');
    DeviceSession session;
    try {
      session = await _deviceSessionService.currentSession();
    } catch (error, stackTrace) {
      // Device metadata is optional; it must never prevent email login.
      debugPrint('AUTH: device session unavailable, using fallback: $error');
      debugPrintStack(stackTrace: stackTrace);
      session = const DeviceSession(
        sessionId: 'android-local-fallback',
        platform: 'Android',
        deviceName: 'Android device',
        model: '',
        manufacturer: '',
        osVersion: '',
        locationLabel: 'Unavailable',
        latitude: null,
        longitude: null,
      );
    }
    debugPrint('AUTH: device session ready');
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
  Future<AuthSession> signInWithFacebook() async {
    if (_facebookAppId.isEmpty) {
      throw const AuthException(
        'Facebook sign-in is not configured in this build. '
        'Add a Facebook App ID to enable it.',
        code: 'FACEBOOK_NOT_CONFIGURED',
      );
    }
    final token = await _requestFacebookToken();
    if (token == null) {
      // The user closed the Facebook dialog. Treated as a cancellation rather
      // than an error, so no scary message appears for an intentional exit.
      throw const AuthException(
        'Facebook sign-in was cancelled.',
        code: 'FACEBOOK_CANCELLED',
      );
    }
    final session = await _deviceSessionService.currentSession();
    final response = await _post('/api/v1/auth/facebook', {
      'accessToken': token,
      'deviceId': session.sessionId,
      'deviceName': session.deviceName,
    });
    return _handleTokenResponse(response);
  }

  /// Returns a Facebook user access token, or null when the user dismissed the
  /// login dialog. The native SDK owns the token lifecycle, so the token is
  /// requested fresh each time rather than cached.
  Future<String?> _requestFacebookToken() async {
    final facebookAuth = FacebookAuth.instance;
    // Only the web build needs the JavaScript SDK primed by hand; on Android
    // the native SDK starts itself from the manifest configuration.
    if (kIsWeb) {
      await facebookAuth.webAndDesktopInitialize(
        appId: _facebookAppId,
        cookie: true,
        xfbml: false,
        version: 'v21.0',
      );
    }

    LoginResult result;
    try {
      result = await facebookAuth.login();
    } on PlatformException catch (error) {
      // The plugin reports cancellations and failures as platform exceptions;
      // its own converter turns them back into the same result shape.
      result = LoginResult.getResultFromException(error);
    }

    switch (result.status) {
      case LoginStatus.success:
        final token = result.accessToken?.tokenString;
        if (token == null || token.isEmpty) {
          throw const AuthException(
            'Facebook did not return a usable session. Please try again.',
            code: 'FACEBOOK_NO_TOKEN',
          );
        }
        return token;
      case LoginStatus.cancelled:
        return null;
      case LoginStatus.operationInProgress:
        throw const AuthException(
          'Facebook sign-in is already in progress.',
          code: 'FACEBOOK_BUSY',
        );
      case LoginStatus.failed:
        throw AuthException(
          result.message ?? 'Facebook sign-in failed. Please try again.',
          code: 'FACEBOOK_FAILED',
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
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _post('/api/v1/auth/reset-password', {
      'email': email.trim().toLowerCase(),
      'code': code.trim(),
      'newPassword': newPassword,
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
    final refreshToken = TokenStore.get(_kRefreshToken);
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
    try {
      debugPrint('AUTH: POST $_baseUrl$path');
      final client = await secureHttpClient();
      return await _request(
        () => client.post(
          _uri(path),
          headers: {
            'Content-Type': 'application/json',
            if (authenticated)
              'Authorization': 'Bearer ${TokenStore.get(_kAccessToken)}',
          },
          body: jsonEncode(body),
        ),
        path: path,
        body: body,
      );
    } on SocketException catch (error) {
      debugPrint('AUTH: socket error for $path: $error');
      throw const AuthException(
        'Cannot reach the sign-in server. Please check your internet '
        'connection and try again.',
        code: 'AUTH_SERVICE_UNREACHABLE',
      );
    } on HandshakeException catch (error) {
      debugPrint('AUTH: TLS handshake failed for $path: $error');
      throw const AuthException(
        'The secure connection to the sign-in server failed. Please try again.',
        code: 'AUTH_TLS_FAILED',
      );
    } on AuthException {
      // Real auth failures (invalid credentials, expired session, server-side
      // validation…) already carry a meaningful message. Let them through
      // untouched instead of wrapping them in a generic "client error".
      rethrow;
    } on http.ClientException catch (error, stackTrace) {
      debugPrint(
        'AUTH: HTTP client exception message=${error.message} '
        'uri=${error.uri} full=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      throw const AuthException(
        'Cannot reach the sign-in server. Please check your internet '
        'connection and try again.',
        code: 'AUTH_NETWORK_UNREACHABLE',
      );
    } on TimeoutException {
      throw const AuthException(
        'The sign-in server is taking too long to respond. Please try again.',
        code: 'AUTH_SERVICE_TIMEOUT',
      );
    } on Object catch (error, stackTrace) {
      debugPrint('AUTH: client failure for $path: $error');
      debugPrintStack(stackTrace: stackTrace);
      throw const AuthException(
        'Something went wrong while signing in. Please try again.',
        code: 'AUTH_CLIENT_ERROR',
      );
    }
  }

  Future<Map<String, dynamic>> _request(
    Future<http.Response> Function() send, {
    required String path,
    Map<String, dynamic>? body,
  }) async {
    final response = await send().timeout(AppConfig.authTimeout);
    if (response.statusCode == 401 && TokenStore.get(_kRefreshToken) != null) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final retry = await send().timeout(AppConfig.authTimeout);
        return _decode(retry, path);
      }
    }
    return _decode(response, path);
  }

  /// Single-flight refresh: concurrent 401s share ONE refresh call. Racing
  /// refreshes against the auth service's refresh-token rotation revokes the
  /// token mid-flight and wipes the session.
  Future<bool>? _refreshFuture;

  Future<bool> _tryRefresh() {
    return _refreshFuture ??= _doRefresh().whenComplete(() {
      _refreshFuture = null;
    });
  }

  Future<bool> _doRefresh() async {
    final refreshToken = TokenStore.get(_kRefreshToken);
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
        // Only wipe the session when the auth service definitively rejects
        // the refresh token (401/403). A transient 5xx must NOT log the user
        // out — the tokens stay and a later request retries.
        if (response.statusCode == 401 || response.statusCode == 403) {
          await _clearTokens();
          _sessionController.add(null);
        }
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
    await TokenStore.put(_kAccessToken, access);
    await TokenStore.put(_kRefreshToken, refresh);
    final user = data['user'];
    if (user is Map<String, dynamic>) {
      await TokenStore.put(
        _kSession,
        jsonEncode({
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
        }),
      );
    }
    _sessionController.add(_sessionFromHive());
  }

  Future<void> _clearTokens() async {
    await TokenStore.remove(_kAccessToken);
    await TokenStore.remove(_kRefreshToken);
    await TokenStore.remove(_kSession);
    await _settings.delete(_kAccessToken);
    await _settings.delete(_kRefreshToken);
    await _settings.delete(_kSession);
  }
}
