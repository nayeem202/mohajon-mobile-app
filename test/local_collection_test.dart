import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:inventory_1/core/models/customer.dart';
import 'package:inventory_1/core/models/syncable.dart';
import 'package:inventory_1/core/offline/local_collection.dart';

void main() {
  late Directory directory;
  late Box<Map> box;
  late LocalCollection<Customer> collection;
  Customer customer(
    String shop, {
    int day = 1,
    String name = 'Local',
    bool deleted = false,
    SyncStatus status = SyncStatus.pending,
  }) => Customer(
    customerId: 'same-id',
    name: name,
    phone: '',
    shopId: shop,
    updatedAt: DateTime.utc(2026, 10, day),
    syncStatus: status,
    isDeleted: deleted,
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mohajon-qa-hive-');
    // Flutter test files run in isolated VMs; only this disposable path is used.
    Hive.init(directory.path);
    box = await Hive.openBox<Map>('qa-customers');
    collection = LocalCollection(box, Customer.fromJson);
  });
  tearDown(() async {
    await box.close();
    await directory.delete(recursive: true);
  });

  test(
    'SYNC-01 identical IDs remain isolated across shops and removal',
    () async {
      await collection.put(customer('shop-a'));
      await collection.put(customer('shop-b', name: 'Other'));
      expect(collection.getForShop('shop-a', 'same-id')!.name, 'Local');
      expect(collection.pendingForShop('shop-b').single.name, 'Other');
      await collection.remove('shop-a', 'same-id');
      expect(collection.valuesForShop('shop-a'), isEmpty);
      expect(collection.valuesForShop('shop-b'), hasLength(1));
    },
  );
  test('SYNC-02 newer pull never overwrites an unpushed local edit', () async {
    await collection.put(customer('shop-a'));
    await collection.mergeRemote(
      customer('shop-a', day: 2, name: 'Server').toJson(),
    );
    expect(collection.getForShop('shop-a', 'same-id')!.name, 'Local');
    expect(collection.pendingForShop('shop-a'), hasLength(1));
  });
  test('SYNC-03 pending tombstone survives a newer remote document', () async {
    await collection.put(customer('shop-a', deleted: true));
    await collection.mergeRemote(customer('shop-a', day: 2).toJson());
    expect(collection.valuesForShop('shop-a'), isEmpty);
    expect(collection.pendingForShop('shop-a').single.isDeleted, isTrue);
  });
  test('SYNC-04 synced data accepts only a newer remote edit', () async {
    await collection.putSynced(customer('shop-a', day: 2));
    for (final day in [1, 2]) {
      await collection.mergeRemote(
        customer('shop-a', day: day, name: 'Stale').toJson(),
      );
      expect(collection.getForShop('shop-a', 'same-id')!.name, 'Local');
    }
    await collection.mergeRemote(
      customer('shop-a', day: 3, name: 'Fresh').toJson(),
    );
    expect(collection.getForShop('shop-a', 'same-id')!.name, 'Fresh');
    expect(collection.pendingForShop('shop-a'), isEmpty);
  });
  test('SYNC-05 server tombstones are hidden and never pending', () async {
    await collection.putSynced(customer('shop-a'));
    await collection.mergeRemote(
      customer('shop-a', day: 2, deleted: true).toJson(),
    );
    expect(collection.valuesForShop('shop-a'), isEmpty);
    expect(
      collection.valuesForShop('shop-a', includeDeleted: true).single.isDeleted,
      isTrue,
    );
    expect(collection.pending(), isEmpty);
  });
  test('SYNC-01 shop-scoped watcher emits only that shop data', () async {
    final events = collection.watchForShop('shop-a').take(3).toList();
    await Future<void>.delayed(Duration.zero);
    await collection.put(customer('shop-b'));
    await collection.put(customer('shop-a'));
    final snapshots = await events;
    expect(snapshots[0], isEmpty);
    expect(snapshots[1], isEmpty);
    expect(snapshots[2].single.shopId, 'shop-a');
  });
}
