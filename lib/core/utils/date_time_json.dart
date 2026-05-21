DateTime dateFromJson(Object? value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  try {
    final dynamic timestamp = value;
    final converted = timestamp?.toDate();
    if (converted is DateTime) return converted;
  } catch (_) {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

String dateToJson(DateTime value) => value.toUtc().toIso8601String();
