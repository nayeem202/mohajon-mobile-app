import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:inventory_1/core/services/accounting_outbox.dart';
import 'package:inventory_1/core/services/api_client.dart';
import 'package:inventory_1/features/accounting/data/accounting_client.dart';

void main() {
  late Directory temp;
  late Box<dynamic> box;
  final payload = <String, dynamic>{
    'entryId': 'stable-id',
    'entryType': 'CAPITAL_IN',
    'amount': 100,
  };
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('mohajon-accounting-');
    Hive.init(temp.path);
    box = await Hive.openBox('settings');
    await box.putAll({
      'activeShopId': 's',
      'activeUserId': 'u',
      'activeBranchId': 'b',
    });
  });
  tearDown(() async {
    await box.close();
    await temp.delete(recursive: true);
  });
  AccountingClient client({
    bool online = true,
    AccountingGet? get,
    AccountingPost? post,
  }) => AccountingClient(
    settings: box,
    shopId: 's',
    branchId: 'b',
    userId: 'u',
    online: () async => online,
    get:
        get ??
        (path, query) async => {
          'configured': true,
          'branchId': 'b',
          'netProfit': 42,
        },
    post: post ?? (path, body) async => {'configured': true},
  );
  test(
    'reports use marked cached snapshot offline, never fabricated zero',
    () async {
      await client().report('income', '2026-10-01', '2026-10-23');
      expect(
        (await client(
          online: false,
        ).report('income', '2026-10-01', '2026-10-23'))['_cached'],
        true,
      );
      await expectLater(
        client(online: false).report('balance', '2026-10-01', '2026-10-22'),
        throwsA(isA<ApiException>()),
      );
    },
  );
  for (final status in [401, 403]) {
    test('HTTP $status never falls back to private cached data', () async {
      await client().state();
      await expectLater(
        client(
          get: (p, q) async =>
              throw ApiException(status, 'FORBIDDEN', 'private'),
        ).state(),
        throwsA(isA<ApiException>()),
      );
    });
  }
  test(
    'inflight branch switch cannot write cache into a different scope',
    () async {
      final response = Completer<Map<String, dynamic>>();
      final pending = client(get: (p, q) => response.future).state();
      await Future<void>.delayed(Duration.zero);
      await box.put('activeBranchId', 'other');
      response.complete({'configured': true});
      await expectLater(pending, throwsStateError);
      expect(
        box.keys.where((k) => '$k'.startsWith('accounting.cache')),
        isEmpty,
      );
    },
  );
  test(
    'lost server response queues identical UUID and concurrent flush runs once',
    () async {
      final api = client(
        post: (p, b) async => throw const SocketException('lost response'),
      );
      expect(await api.addEntry(payload), false);
      final gate = Completer<Map<String, dynamic>>();
      var calls = 0;
      final outbox = AccountingOutbox(box, (p, b) {
        calls++;
        expect(b, payload);
        return gate.future;
      });
      final one = outbox.flush('s', 'b', 'u');
      final two = outbox.flush('s', 'b', 'u');
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      gate.complete({});
      expect(await one, 0);
      expect(await two, 0);
      expect(outbox.pending('s', 'b', 'u'), isEmpty);
    },
  );
  test('commands queued during a flush are retained', () async {
    final gate = Completer<Map<String, dynamic>>();
    final outbox = AccountingOutbox(box, (p, b) => gate.future);
    await outbox.enqueue('s', 'b', 'u', payload);
    final flush = outbox.flush('s', 'b', 'u');
    await Future<void>.delayed(Duration.zero);
    await outbox.enqueue('s', 'b', 'u', {...payload, 'entryId': 'next'});
    gate.complete({});
    await flush;
    expect(outbox.pending('s', 'b', 'u').single['payload']['entryId'], 'next');
  });
  test(
    'validation rejection is kept for correction and does not auto retry',
    () async {
      var calls = 0;
      final outbox = AccountingOutbox(box, (p, b) async {
        calls++;
        throw const ApiException(400, 'BAD_REQUEST', 'invalid');
      });
      await outbox.enqueue('s', 'b', 'u', payload);
      await outbox.flush('s', 'b', 'u');
      await outbox.flush('s', 'b', 'u');
      expect(calls, 1);
      expect(outbox.pending('s', 'b', 'u').single['status'], 'needsReview');
      await outbox.enqueue('s', 'b', 'u', {...payload, 'amount': 50});
      expect(outbox.pending('s', 'b', 'u').single['status'], 'pending');
    },
  );
  test(
    'uncertain content cannot change and another branch cannot flush it',
    () async {
      var calls = 0;
      final outbox = AccountingOutbox(box, (p, b) async {
        calls++;
        return {};
      });
      await outbox.enqueue('s', 'b', 'u', payload);
      await expectLater(
        outbox.enqueue('s', 'b', 'u', {...payload, 'amount': 50}),
        throwsStateError,
      );
      await box.put('activeBranchId', 'other');
      expect(await outbox.flush('s', 'b', 'u'), 1);
      expect(calls, 0);
    },
  );
}
