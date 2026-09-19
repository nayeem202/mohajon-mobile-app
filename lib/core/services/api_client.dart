import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../offline/local_database.dart';
import 'secure_http.dart';
import 'secure_tokens.dart';

/// Thrown when the Haalkhata business service returns a non-2xx response.
class ApiException implements Exception {
  const ApiException(this.statusCode, this.code, this.message);

  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}

/// HTTP client for the Haalkhata business service.
///
/// Attaches the stored JWT access token, transparently refreshes it when a
/// request fails with 401, and decodes server error responses into
/// [ApiException].
class ApiClient {
  ApiClient(this._db);

  final LocalDatabase _db;

  /// Invoked when the stored session is wiped because the refresh token was
  /// definitively rejected. The auth layer listens and signs the UI out with
  /// a clear message instead of leaving random 403 errors on screen.
  static void Function()? onSessionInvalidated;

  static const _kAccessToken = 'auth_access_token';
  static const _kRefreshToken = 'auth_refresh_token';
  static const _kSession = 'auth_session';
  static const _timeout = Duration(seconds: 20);

  Box<dynamic> get _settings => _db.settings;

  String get _baseUrl => AppConfig.apiBaseUrl;

  String? get accessToken => TokenStore.get(_kAccessToken);

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$_baseUrl$path').replace(queryParameters: query);

  /// Decodes a response body that may be a JSON object or array.
  Future<dynamic> getJson(
    String path, {
    Map<String, String>? query,
    Duration? timeout,
  }) async {
    final client = await secureHttpClient();
    return _send(
      () => client.get(_uri(path, query), headers: _headers()),
      path: path,
      timeout: timeout,
    );
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    Duration? timeout,
  }) async {
    final data = await getJson(path, query: query, timeout: timeout);
    return (data is Map<String, dynamic>) ? data : const {};
  }

  /// Downloads a binary payload (e.g. a server-rendered PDF/XLSX report).
  ///
  /// Returns `null` when the response is empty. Throws [ApiException] on
  /// non-2xx responses (the caller decides whether to fall back offline).
  Future<Uint8List?> getBytes(
    String path, {
    Map<String, String>? query,
    Duration? timeout,
  }) async {
    final client = await secureHttpClient();
    var response = await client
        .get(_uri(path, query), headers: _headers())
        .timeout(timeout ?? _timeout);
    if ((response.statusCode == 401 || response.statusCode == 403) &&
        TokenStore.get(_kRefreshToken) != null) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        response = await client
            .get(_uri(path, query), headers: _headers())
            .timeout(timeout ?? _timeout);
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.bodyBytes.isEmpty) return null;
      return response.bodyBytes;
    }
    throw ApiException(
      response.statusCode,
      'download_failed',
      'Download failed ($path).',
    );
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    Duration? timeout,
  }) async {
    final client = await secureHttpClient();
    final data = await _send(
      () => client.post(
        _uri(path),
        headers: _headers(json: true),
        body: jsonEncode(body),
      ),
      path: path,
      timeout: timeout,
    );
    return (data is Map<String, dynamic>) ? data : const {};
  }

  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body,
  ) async {
    final client = await secureHttpClient();
    final data = await _send(
      () => client.put(
        _uri(path),
        headers: _headers(json: true),
        body: jsonEncode(body),
      ),
      path: path,
    );
    return (data is Map<String, dynamic>) ? data : const {};
  }

  Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body,
  ) async {
    final client = await secureHttpClient();
    final data = await _send(
      () => client.patch(
        _uri(path),
        headers: _headers(json: true),
        body: jsonEncode(body),
      ),
      path: path,
    );
    return (data is Map<String, dynamic>) ? data : const {};
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final client = await secureHttpClient();
    final data = await _send(
      () => client.delete(_uri(path), headers: _headers()),
      path: path,
    );
    return (data is Map<String, dynamic>) ? data : const {};
  }

  /// Uploads [file] as multipart field `file` and returns the decoded JSON
  /// (e.g. `{url, fileName}`).
  Future<Map<String, dynamic>> uploadFile(String path, File file) async {
    final client = await secureHttpClient();
    Future<http.Response> sendUpload() async {
      final request = http.MultipartRequest('POST', _uri(path))
        ..headers.addAll(_headers())
        ..files.add(await http.MultipartFile.fromPath('file', file.path));
      final streamed = await client.send(request).timeout(_timeout);
      return http.Response.fromStream(streamed);
    }

    var response = await sendUpload();
    if ((response.statusCode == 401 || response.statusCode == 403) &&
        TokenStore.get(_kRefreshToken) != null) {
      final refreshed = await _tryRefresh();
      if (refreshed) response = await sendUpload();
    }
    final data = _decode(response, path);
    return (data is Map<String, dynamic>) ? data : const {};
  }

  Map<String, String> _headers({bool json = false}) => {
    'Authorization': 'Bearer ${accessToken ?? ''}',
    if (json) 'Content-Type': 'application/json',
  };

  Future<dynamic> _send(
    Future<http.Response> Function() send, {
    required String path,
    Duration? timeout,
  }) async {
    var response = await send().timeout(timeout ?? _timeout);
    if ((response.statusCode == 401 || response.statusCode == 403) &&
        TokenStore.get(_kRefreshToken) != null) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        response = await send().timeout(timeout ?? _timeout);
      }
    }
    return _decode(response, path);
  }

  /// Single-flight refresh: when many requests hit 401/403 at once (e.g.
  /// parallel polling), they all await this ONE refresh instead of racing.
  /// Racing causes the auth service's refresh-token rotation to revoke the
  /// token mid-flight and wipe the session.
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
            Uri.parse('${AppConfig.authBaseUrl}/api/v1/auth/refresh'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(_timeout);
      if (response.statusCode != 200) {
        // Only wipe the session when the server definitively rejects the
        // refresh token. Transient failures keep tokens so we can retry.
        if (response.statusCode == 401 || response.statusCode == 403) {
          await _clearTokens();
        }
        return false;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final access = (data['accessToken'] ?? '') as String;
      final refresh = (data['refreshToken'] ?? '') as String;
      await TokenStore.put(_kAccessToken, access);
      await TokenStore.put(_kRefreshToken, refresh);
      return true;
    } catch (_) {
      // Network/timeout error — keep tokens and let a later request retry.
      return false;
    }
  }

  dynamic _decode(http.Response response, String path) {
    dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      // Non-JSON body (e.g. empty 204).
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data ?? const <String, dynamic>{};
    }
    final body = data is Map<String, dynamic> ? data : const <String, dynamic>{};
    final code = (body['code'] ?? 'ERROR').toString();
    final message = (body['message'] ?? 'Request failed ($path).').toString();
    throw ApiException(response.statusCode, code, message);
  }

  /// Wipes tokens from the keychain first, then any legacy plaintext Hive
  /// copies so a downgraded build can never re-read a stale token.
  Future<void> _clearTokens() async {
    await TokenStore.remove(_kAccessToken);
    await TokenStore.remove(_kRefreshToken);
    await TokenStore.remove(_kSession);
    await _settings.delete(_kAccessToken);
    await _settings.delete(_kRefreshToken);
    await _settings.delete(_kSession);
    onSessionInvalidated?.call();
  }
}

/// Emits [fetch]'s latest result immediately and then every [interval].
/// Errors are swallowed so the stream keeps its previous value (offline-safe).
Stream<T> pollStream<T>(Future<T> Function() fetch, Duration interval) async* {
  while (true) {
    try {
      yield await fetch();
    } catch (_) {
      // Keep the last emitted value.
    }
    await Future<void>.delayed(interval);
  }
}
