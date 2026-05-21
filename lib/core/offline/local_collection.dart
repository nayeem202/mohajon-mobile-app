import 'package:hive/hive.dart';

import '../models/syncable.dart';

typedef FromJson<T> = T Function(Map<dynamic, dynamic> json);

class LocalCollection<T extends Syncable> {
  LocalCollection(this._box, this._fromJson);

  final Box<Map> _box;
  final FromJson<T> _fromJson;

  List<T> watchableValues() => values();

  Stream<List<T>> watch() async* {
    yield values();
    yield* _box.watch().map((_) => values());
  }

  Stream<List<T>> watchForShop(String shopId) async* {
    yield valuesForShop(shopId);
    yield* _box.watch().map((_) => valuesForShop(shopId));
  }

  List<T> values({bool includeDeleted = false}) {
    return _box.values
        .map((value) => _fromJson(value))
        .where((item) => includeDeleted || item.toJson()['isDeleted'] != true)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  List<T> valuesForShop(String shopId, {bool includeDeleted = false}) {
    return values(includeDeleted: includeDeleted)
        .where((item) => item.shopId == shopId)
        .toList();
  }

  String _keyFor(T item) => '${item.shopId}:${item.id}';

  T? get(String id) {
    final value = _box.get(id);
    return value == null ? null : _fromJson(value);
  }

  T? getForShop(String shopId, String id) {
    final value = _box.get('$shopId:$id');
    if (value != null) return _fromJson(value);
    for (final item in valuesForShop(shopId, includeDeleted: true)) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> put(T item) => _box.put(_keyFor(item), item.toJson());

  Future<void> clear() => _box.clear();

  Future<void> putSynced(T item) {
    final json = item.toJson()..['syncStatus'] = SyncStatus.synced.value;
    return _box.put(_keyFor(item), json);
  }

  List<T> pending() => values(includeDeleted: true)
      .where((item) => item.syncStatus == SyncStatus.pending)
      .toList();

  List<T> pendingForShop(String shopId) => valuesForShop(
        shopId,
        includeDeleted: true,
      ).where((item) => item.syncStatus == SyncStatus.pending).toList();

  Future<void> mergeRemote(Map<String, dynamic> remote) async {
    final remoteItem = _fromJson(remote);
    final local = getForShop(remoteItem.shopId, remoteItem.id);
    if (local == null || remoteItem.updatedAt.isAfter(local.updatedAt)) {
      final json = remoteItem.toJson()..['syncStatus'] = SyncStatus.synced.value;
      await _box.put(_keyFor(remoteItem), json);
    }
  }
}
