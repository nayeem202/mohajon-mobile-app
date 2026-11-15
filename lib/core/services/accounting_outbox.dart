import 'dart:convert';
import 'package:hive/hive.dart';
import 'api_client.dart';

typedef AccountingPost =
    Future<Map<String, dynamic>> Function(
      String path,
      Map<String, dynamic> body,
    );

/// Separate from collection sync: immutable financial commands retain the same
/// UUID across retries, including a lost response after a committed transaction.
class AccountingOutbox {
  AccountingOutbox(this.settings, this.post);
  final Box<dynamic> settings;
  final AccountingPost post;
  static const prefix = 'accounting.outbox.';
  static final Map<String, Future<int>> _running = {};
  static final Set<String> _sending = {};
  String _scope(String shop, String branch, String user) =>
      '${identityHashCode(settings)}:${key(shop, branch, user)}';

  static String key(String shop, String branch, String user) =>
      '$prefix$shop|$branch|$user';
  List<Map<String, dynamic>> pending(String shop, String branch, String user) {
    final raw = settings.get(key(shop, branch, user));
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  static int count(Box<dynamic> settings, {String? shop}) {
    var result = 0;
    for (final name in settings.keys.map((key) => key.toString())) {
      if (!name.startsWith(shop == null ? prefix : '$prefix$shop|')) continue;
      final value = settings.get(name);
      if (value is List) result += value.length;
    }
    return result;
  }

  Future<void> enqueue(
    String shop,
    String branch,
    String user,
    Map<String, dynamic> payload,
  ) async {
    final records = pending(shop, branch, user);
    final id = payload['entryId'];
    if (_sending.contains('${_scope(shop, branch, user)}:$id')) {
      throw StateError(
        'Wait for this transaction to finish syncing before editing it.',
      );
    }
    final index = records.indexWhere(
      (row) => (row['payload'] as Map?)?['entryId'] == id,
    );
    final command = {
      'payload': Map<String, dynamic>.from(payload),
      'queuedAt': DateTime.now().toIso8601String(),
      'status': 'pending',
    };
    if (index < 0) {
      records.add(command);
    } else {
      final old = records[index];
      if (jsonEncode(old['payload']) != jsonEncode(payload) &&
          old['httpStatus'] != 400) {
        throw StateError(
          'An uncertain transaction must retain its original content until reconciled.',
        );
      }
      records[index] = command;
    }
    await settings.put(key(shop, branch, user), records);
  }

  Future<int> flush(String shop, String branch, String user) {
    final scope = _scope(shop, branch, user);
    return _running.putIfAbsent(
      scope,
      () => _flush(shop, branch, user).whenComplete(() {
        _running.remove(scope);
      }),
    );
  }

  Future<int> _flush(String shop, String branch, String user) async {
    final records = pending(shop, branch, user);
    for (final command in List<Map<String, dynamic>>.from(records)) {
      // Rejected input requires an explicit edit, not repeated automatic posts.
      if (command['status'] == 'needsReview' && command['httpStatus'] == 400) {
        continue;
      }
      // Never send a queued command with another account/branch's auth header.
      if (settings.get('activeShopId') != shop ||
          settings.get('activeUserId') != user ||
          (settings.get('activeBranchId') ?? '$shop-main') != branch) {
        break;
      }
      final sending =
          '${_scope(shop, branch, user)}:${(command['payload'] as Map)['entryId']}';
      _sending.add(sending);
      try {
        await post(
          '/api/v1/accounting/entries',
          Map<String, dynamic>.from(command['payload'] as Map),
        );
        records.remove(command);
      } on ApiException catch (error) {
        command['status'] = error.statusCode >= 400 && error.statusCode < 500
            ? 'needsReview'
            : 'pending';
        command['httpStatus'] = error.statusCode;
        command['errorCode'] = error.code;
      } catch (_) {
        command['status'] = 'pending';
      } finally {
        _sending.remove(sending);
      }
      // Merge with commands queued while this request was in flight.
      final latest = pending(shop, branch, user);
      final attempted = (command['payload'] as Map)['entryId'];
      final output = latest
          .where((row) => (row['payload'] as Map)['entryId'] != attempted)
          .toList();
      if (records.contains(command)) output.add(command);
      await settings.put(key(shop, branch, user), output);
    }
    return pending(shop, branch, user).length;
  }
}
