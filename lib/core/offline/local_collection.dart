import 'package:hive/hive.dart';

import '../models/syncable.dart';

typedef FromJson<T> = T Function(Map<dynamic, dynamic> json);

class LocalCollection<T extends Syncable> {
  LocalCollection(this._box, this._fromJson);

  final Box<Map> _box;
  final FromJson<T> _fromJson;

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

  T? getForShop(String shopId, String id) {
    final value = _box.get('$shopId:$id');
    if (value != null) return _fromJson(value);
    for (final item in valuesForShop(shopId, includeDeleted: true)) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> put(T item) => _box.put(_keyFor(item), item.toJson());

  Future<void> remove(String shopId, String id) => _box.delete('$shopId:$id');

  Future<void> clear() => _box.clear();

  Future<void> putSynced(T item) {
    final json = item.toJson()..['syncStatus'] = SyncStatus.synced.value;
    return _box.put(_keyFor(item), json);
  }

  /// Persists an already-server-authoritative document (e.g. a product whose
  /// local offline photo was just uploaded, so the saved imagePath is the new
  /// server URL — not the local filesystem path the [T] object still holds).
  Future<void> putRemoteJson(
    String shopId,
    String id,
    Map<String, dynamic> json,
  ) {
    return _box.put(
      '$shopId:$id',
      json..['syncStatus'] = SyncStatus.synced.value,
    );
  }

  Future<void> putRawPending(String shopId, String id, Map<String, dynamic> json) {
    final copy = Map<String, dynamic>.from(json)..['syncStatus'] = SyncStatus.pending.value;
    return _box.put('$shopId:$id', copy);
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
    // A pending local document holds this device's newest user intent and has
    // not reached the server yet (push failed or was quarantined). Never let a
    // pull clobber it — it gets pushed and wins on the next sync.
    if (local is T && local.syncStatus == SyncStatus.pending) {
      return;
    }
    if (local == null || remoteItem.updatedAt.isAfter(local.updatedAt)) {
      final json = remoteItem.toJson()..['syncStatus'] = SyncStatus.synced.value;
      await _box.put(_keyFor(remoteItem), json);
    }
  }
}
