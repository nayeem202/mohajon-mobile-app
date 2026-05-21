enum SyncStatus { pending, synced }

extension SyncStatusX on SyncStatus {
  String get value => name;

  static SyncStatus parse(Object? value) {
    return SyncStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => SyncStatus.pending,
    );
  }
}

mixin Syncable {
  String get id;
  String get shopId;
  DateTime get updatedAt;
  SyncStatus get syncStatus;
  Map<String, dynamic> toJson();
}
