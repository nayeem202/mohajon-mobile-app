import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../offline/local_database.dart';
import 'secure_http.dart';
import 'secure_tokens.dart';
import 'session_token_refresher.dart';

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

  Future<http.Client> _requestClient() async {
    // Fail quickly on devices with no network instead of leaving cloud-backed
    // screens (branches, subscription, support, etc.) spinning for 20 seconds.
    // Keep localhost available for local services reached through adb reverse.
    final endpoint = Uri.tryParse(_baseUrl);
    final isLocalEndpoint =
        endpoint != null &&
        (endpoint.host == 'localhost' ||
            endpoint.host == '127.0.0.1' ||
            endpoint.host == '::1');
    if (!isLocalEndpoint) {
      try {
        final connections = await Connectivity().checkConnectivity().timeout(
          const Duration(milliseconds: 500),
        );
        if (connections.every((item) => item == ConnectivityResult.none)) {
          throw const ApiException(
            0,
            'NO_INTERNET',
            'Internet is required for this feature.',
          );
        }
      } on ApiException {
        rethrow;
      } catch (_) {
        // OS connectivity is a hint only; attempt the actual request if the
        // connectivity plugin is unavailable or slow to respond.
      }
    }
    return secureHttpClient();
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$_baseUrl$path').replace(queryParameters: query);

  /// Decodes a response body that may be a JSON object or array.
  Future<dynamic> getJson(
    String path, {
    Map<String, String>? query,
    Duration? timeout,
  }) async {
    final client = await _requestClient();
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
    final client = await _requestClient();
    final sentAccessToken = accessToken;
    var response = await client
        .get(_uri(path, query), headers: _headers())
        .timeout(timeout ?? _timeout);
    if (response.statusCode == 401) {
      if (await _recoverFromUnauthorized(sentAccessToken)) {
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
    final client = await _requestClient();
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
    final client = await _requestClient();
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
    final client = await _requestClient();
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
    final client = await _requestClient();
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

    final sentAccessToken = accessToken;
    var response = await sendUpload();
    if (response.statusCode == 401) {
      if (await _recoverFromUnauthorized(sentAccessToken)) {
        response = await sendUpload();
      }
    }
    final data = _decode(response, path);
    return (data is Map<String, dynamic>) ? data : const {};
  }

  Map<String, String> _headers({bool json = false}) {
    final activeBranchId = _settings.get('activeBranchId') as String?;
    final activeShopId = _settings.get('activeShopId') as String?;
    final branchShopId = _settings.get('activeBranchShopId') as String?;
    final branchBelongsToActiveShop =
        activeBranchId != null &&
        activeBranchId.isNotEmpty &&
        activeShopId != null &&
        activeShopId.isNotEmpty &&
        branchShopId == activeShopId;

    return {
      'Authorization': 'Bearer ${accessToken ?? ''}',
      if (branchBelongsToActiveShop) 'X-Branch-Id': activeBranchId,
      if (json) 'Content-Type': 'application/json',
    };
  }

  Future<dynamic> _send(
    Future<http.Response> Function() send, {
    required String path,
    Duration? timeout,
  }) async {
    final sentAccessToken = accessToken;
    var response = await send().timeout(timeout ?? _timeout);
    if (response.statusCode == 401) {
      if (await _recoverFromUnauthorized(sentAccessToken)) {
        response = await send().timeout(timeout ?? _timeout);
      }
    }
    return _decode(response, path);
  }

  /// Recovers from a 401/403, or gives up and signs the session out.
  ///
  /// Returns `true` when a fresh access token was stored and the request is
  /// worth replaying. Returns `false` once the session has been wiped, which is
  /// the only way out of the "no refresh token, still holding an access token"
  /// state: without this, a request whose refresh token is missing fails the
  /// guard below, never clears anything, and 401-loops until the app is killed.
  ///
  /// Wiping is deliberately left to the caller so [onSessionInvalidated] fires
  /// exactly once for a dead session rather than once per rejected request.
  Future<bool> _recoverFromUnauthorized(String? rejectedAccessToken) async {
    if (TokenStore.get(_kRefreshToken) == null) {
      // Nothing left to recover with: the access token is dead and there is no
      // way to mint a replacement, so this session can never succeed.
      await _clearTokens();
      return false;
    }
    switch (await SessionTokenRefresher.recover(
      rejectedAccessToken: rejectedAccessToken,
    )) {
      case SessionRefreshResult.refreshed:
        return true;
      case SessionRefreshResult.rejected:
        // The auth service refused the refresh token. It is spent for good.
        await _clearTokens();
        return false;
      case SessionRefreshResult.unreachable:
        // Offline or the auth service is down. Keep the session so a later
        // request can still recover once connectivity returns — signing out
        // here would punish a flaky network with a lost session.
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
    final body = data is Map<String, dynamic>
        ? data
        : const <String, dynamic>{};
    final code = (body['code'] ?? 'ERROR').toString();
    final message = (body['message'] ?? 'Request failed ($path).').toString();
    throw ApiException(response.statusCode, code, message);
  }

  /// Wipes tokens from the keychain first, then any legacy plaintext Hive
  /// copies so a downgraded build can never re-read a stale token.
  ///
  /// [onSessionInvalidated] only fires when there was actually a session to
  /// wipe, so the pollers that all discover the same dead session at once
  /// produce one sign-out instead of one per in-flight request.
  Future<void> _clearTokens() async {
    final hadSession =
        TokenStore.get(_kAccessToken) != null ||
        TokenStore.get(_kRefreshToken) != null ||
        TokenStore.get(_kSession) != null ||
        _settings.get(_kAccessToken) != null ||
        _settings.get(_kRefreshToken) != null ||
        _settings.get(_kSession) != null;
    await TokenStore.remove(_kAccessToken);
    await TokenStore.remove(_kRefreshToken);
    await TokenStore.remove(_kSession);
    await _settings.delete(_kAccessToken);
    await _settings.delete(_kRefreshToken);
    await _settings.delete(_kSession);
    if (hadSession) onSessionInvalidated?.call();
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
