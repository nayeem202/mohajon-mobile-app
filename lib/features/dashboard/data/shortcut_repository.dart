import 'package:hive_flutter/hive_flutter.dart';

class ShortcutRepository {
  final Box<dynamic> _settings;

  ShortcutRepository(this._settings);

  static const _key = 'shortcut_ids';

  static const List<String> defaultIds = [
    'new_sale',
    'add_product',
    'add_client',
    'stock',
    'clients',
  ];

  List<String> load() {
    final raw = _settings.get(_key);
    if (raw is List) return raw.cast<String>();
    return List.from(defaultIds);
  }

  Future<void> save(List<String> ids) async {
    await _settings.put(_key, ids);
  }
}