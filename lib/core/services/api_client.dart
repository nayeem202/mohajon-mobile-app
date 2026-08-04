import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../offline/local_database.dart';

/// Thrown when the Haalkhata business service returns a non-2xx response.
class ApiException implements Exception {
  const ApiException(this.statusCode, this.code, this.message);

  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() => message;
}

/// HTTP client for the Haalkhata business service.
///
/// Attaches the stored JWT access token, transparently refreshes it when a
/// request fails with 401, and decodes server error responses into
/// [ApiException].
class ApiClient {
  ApiClient(this._db);

  final LocalDatabase _db;

  static const _kAccessToken = 'auth_access_token';
  static const _kRefreshToken = 'auth_refresh_token';
  static const _kSession = 'auth_session';
  static const _timeout = Duration(seconds: 20);

  Box<dynamic> get _settings => _db.settings;

  String get _baseUrl => AppConfig.apiBaseUrl;

  String? get accessToken => _settings.get(_kAccessToken) as String?;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$_baseUrl$path').replace(queryParameters: query);

  /// Decodes a response body that may be a JSON object or array.
  Future<dynamic> getJson(
    String path, {
    Map<String, String>? query,
    Duration? timeout,
  }) async {
    return _send(
      () => http.get(_uri(path, query), headers: _headers()),
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

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final data = await _send(
      () => http.post(
        _uri(path),
        headers: _headers(json: true),
        body: jsonEncode(body),
      ),
      path: path,
    );
    return (data is Map<String, dynamic>) ? data : const {};
  }

  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body,
  ) async {
    final data = await _send(
      () => http.put(
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
    final data = await _send(
      () => http.patch(
        _uri(path),
        headers: _headers(json: true),
        body: jsonEncode(body),
      ),
      path: path,
    );
    return (data is Map<String, dynamic>) ? data : const {};
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final data = await _send(
      () => http.delete(_uri(path), headers: _headers()),
      path: path,
    );
    return (data is Map<String, dynamic>) ? data : const {};
  }

  /// Uploads [file] as multipart field `file` and returns the decoded JSON
  /// (e.g. `{url, fileName}`).
  Future<Map<String, dynamic>> uploadFile(String path, File file) async {
    final request = http.MultipartRequest('POST', _uri(path))
      ..headers.addAll(_headers())
      ..files.add(await http.MultipartFile.fromPath('file', file.path));
    final streamed = await request.send().timeout(_timeout);
    final response = await http.Response.fromStream(streamed);
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
    if (response.statusCode == 401 && _settings.get(_kRefreshToken) != null) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        response = await send().timeout(timeout ?? _timeout);
      }
    }
    return _decode(response, path);
  }

  Future<bool> _tryRefresh() async {
    final refreshToken = _settings.get(_kRefreshToken) as String?;
    if (refreshToken == null) return false;
    try {
      final response = await http
          .post(
            Uri.parse('${AppConfig.authBaseUrl}/api/v1/auth/refresh'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(_timeout);
      if (response.statusCode != 200) {
        await _clearTokens();
        return false;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final access = (data['accessToken'] ?? '') as String;
      final refresh = (data['refreshToken'] ?? '') as String;
      await _settings.put(_kAccessToken, access);
      await _settings.put(_kRefreshToken, refresh);
      return true;
    } catch (_) {
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

  Future<void> _clearTokens() async {
    await _settings.delete(_kAccessToken);
    await _settings.delete(_kRefreshToken);
    await _settings.delete(_kSession);
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
