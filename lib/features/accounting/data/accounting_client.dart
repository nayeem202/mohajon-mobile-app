import 'dart:convert';
import 'package:hive/hive.dart';
import '../../../core/services/accounting_outbox.dart';
import '../../../core/services/api_client.dart';

typedef AccountingGet =
    Future<Map<String, dynamic>> Function(
      String path,
      Map<String, String> query,
    );

class AccountingClient {
  AccountingClient({
    required this.settings,
    required this.shopId,
    required this.branchId,
    required this.userId,
    required this.get,
    required this.post,
    required this.online,
  });
  final Box<dynamic> settings;
  final String shopId, branchId, userId;
  final AccountingGet get;
  final AccountingPost post;
  final Future<bool> Function() online;

  AccountingOutbox get outbox => AccountingOutbox(settings, post);
  String _key(String name) =>
      'accounting.cache.$shopId|$branchId|$userId|$name';
  bool get _sameScope =>
      settings.get('activeShopId') == shopId &&
      settings.get('activeUserId') == userId &&
      (settings.get('activeBranchId') ?? '$shopId-main') == branchId;
  void _checkScope() {
    if (!_sameScope) throw StateError('The active account or branch changed.');
  }

  Future<Map<String, dynamic>> state() =>
      _fetch('state', '/api/v1/accounting/state', {});
  Future<Map<String, dynamic>> journal(String from, String to) => _fetch(
    'journal|$from|$to',
    '/api/v1/accounting/journal',
    {'from': from, 'to': to, 'limit': '100'},
  );
  Future<Map<String, dynamic>> report(
    String kind,
    String from,
    String to,
  ) => _fetch(
    '$kind|$from|$to',
    '/api/v1/accounting/${kind == 'income' ? 'income-statement' : 'balance-sheet'}',
    kind == 'income' ? {'from': from, 'to': to} : {'asOf': to},
  );

  Future<Map<String, dynamic>> _fetch(
    String cache,
    String path,
    Map<String, String> query,
  ) async {
    _checkScope();
    Object? failure;
    if (await online()) {
      try {
        final response = await get(path, query);
        _checkScope();
        await settings.put(_key(cache), jsonEncode(response));
        return {
          ...response,
          '_cached': false,
          '_pending': AccountingOutbox.count(settings, shop: shopId),
        };
      } on ApiException catch (error) {
        // Permission/session rejection must not silently fall back to private reports.
        if (error.statusCode >= 400 && error.statusCode < 500) rethrow;
        failure = error;
      } catch (error) {
        failure = error;
      }
    }
    _checkScope();
    final raw = settings.get(_key(cache));
    if (raw is String) {
      try {
        final cached = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        return {
          ...cached,
          '_cached': true,
          '_pending': AccountingOutbox.count(settings, shop: shopId),
        };
      } on FormatException {
        /* Invalid cache is not an empty financial statement. */
      }
    }
    if (failure != null) throw failure;
    throw const ApiException(
      0,
      'NO_INTERNET',
      'Connect to load this accounting period.',
    );
  }

  Future<void> setup(Map<String, dynamic> payload) async {
    _checkScope();
    if (!await online()) {
      throw const ApiException(
        0,
        'NO_INTERNET',
        'Accounting setup requires internet.',
      );
    }
    final response = await post('/api/v1/accounting/setup', payload);
    _checkScope();
    await settings.put(_key('state'), jsonEncode(response));
  }

  /// Returns true only for a confirmed server write. A queued command is not
  /// displayed as an already-posted ledger transaction.
  Future<bool> addEntry(Map<String, dynamic> payload) async {
    _checkScope();
    if (await online()) {
      try {
        final response = await post('/api/v1/accounting/entries', payload);
        _checkScope();
        await settings.put(_key('state'), jsonEncode(response));
        return true;
      } on ApiException catch (error) {
        if (error.statusCode >= 400 && error.statusCode < 500) rethrow;
      } catch (_) {
        _checkScope();
      }
    }
    await outbox.enqueue(shopId, branchId, userId, payload);
    return false;
  }

  Future<void> classify(Map<String, dynamic> payload) async {
    _checkScope();
    if (!await online()) {
      throw const ApiException(
        0,
        'NO_INTERNET',
        'Source review requires internet.',
      );
    }
    final response = await post('/api/v1/accounting/classifications', payload);
    _checkScope();
    await settings.put(_key('state'), jsonEncode(response));
  }

  Future<void> reverse(String id, Map<String, dynamic> payload) async {
    _checkScope();
    if (!await online()) {
      throw const ApiException(0, 'NO_INTERNET', 'Reversal requires internet.');
    }
    final response = await post(
      '/api/v1/accounting/entries/${Uri.encodeComponent(id)}/reverse',
      payload,
    );
    _checkScope();
    await settings.put(_key('state'), jsonEncode(response));
  }
}
