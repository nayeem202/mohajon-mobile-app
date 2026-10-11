import 'dart:async';
import 'dart:convert';

import '../config/app_config.dart';
import 'secure_http.dart';
import 'secure_tokens.dart';

enum SessionRefreshResult { refreshed, rejected, unreachable }

/// Coordinates refresh-token rotation across every API/auth client in this
/// process. Refresh tokens are single-use, so independent client-level locks
/// can otherwise race and invalidate a valid session.
class SessionTokenRefresher {
  SessionTokenRefresher._();

  static const _accessKey = 'auth_access_token';
  static const _refreshKey = 'auth_refresh_token';
  static const _refreshSkew = Duration(minutes: 2);
  static Future<SessionRefreshResult>? _inFlight;

  /// Refresh after a request was rejected with 401. If another request already
  /// rotated tokens since this request was sent, its new access token is enough
  /// and must not trigger a second single-use refresh.
  static Future<SessionRefreshResult> recover({String? rejectedAccessToken}) {
    final currentAccess = TokenStore.get(_accessKey);
    if (rejectedAccessToken != null &&
        currentAccess != null &&
        currentAccess != rejectedAccessToken) {
      return Future.value(SessionRefreshResult.refreshed);
    }
    return _inFlight ??= _perform().whenComplete(() => _inFlight = null);
  }

  /// Called when the app returns to foreground or connectivity comes back.
  /// Does nothing while the access token still has a comfortable lifetime.
  static Future<SessionRefreshResult> refreshIfExpiring() {
    final access = TokenStore.get(_accessKey);
    if (access == null) return Future.value(SessionRefreshResult.rejected);
    final expiry = _jwtExpiry(access);
    if (expiry == null || expiry.isAfter(DateTime.now().add(_refreshSkew))) {
      return Future.value(SessionRefreshResult.refreshed);
    }
    return recover(rejectedAccessToken: access);
  }

  static Future<SessionRefreshResult> _perform() async {
    final refreshToken = TokenStore.get(_refreshKey);
    if (refreshToken == null) return SessionRefreshResult.rejected;
    try {
      final client = await secureHttpClient();
      final response = await client
          .post(
            Uri.parse('${AppConfig.authBaseUrl}/api/v1/auth/refresh'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(AppConfig.authTimeout);
      if (response.statusCode == 401 || response.statusCode == 403) {
        return SessionRefreshResult.rejected;
      }
      if (response.statusCode != 200) return SessionRefreshResult.unreachable;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final access = (data['accessToken'] as String?)?.trim() ?? '';
      final refresh = (data['refreshToken'] as String?)?.trim() ?? '';
      if (access.isEmpty || refresh.isEmpty) {
        return SessionRefreshResult.rejected;
      }
      await TokenStore.put(_accessKey, access);
      await TokenStore.put(_refreshKey, refresh);
      return SessionRefreshResult.refreshed;
    } on Object {
      // Network, timeout, or server failure cannot prove the session is dead.
      return SessionRefreshResult.unreachable;
    }
  }

  static DateTime? _jwtExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is! Map<String, dynamic>) return null;
      final exp = payload['exp'];
      if (exp is! num) return null;
      return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
    } on Object {
      return null;
    }
  }
}
