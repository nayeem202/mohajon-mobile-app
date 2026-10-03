import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/syncable.dart';

class CustomerImportResult {
  const CustomerImportResult({required this.created, required this.skipped, required this.errors});
  final int created;
  final int skipped;
  final List<String> errors;
}

class CustomerImportService {
  CustomerImportService(this._ref, this._uuid);
  final WidgetRef _ref;
  final Uuid _uuid;

  Future<CustomerImportResult> importCsv(String csv) async {
    final lines = csv.split(RegExp(r'\r?\n')).where((line) => line.trim().isNotEmpty).toList();
    if (lines.isEmpty) throw const FormatException('CSV is empty.');
    final header = _split(lines.first).map((item) => item.trim().toLowerCase()).toList();
    final nameIndex = _index(header, ['name', 'customer', 'customer name']);
    final phoneIndex = _index(header, ['phone', 'mobile', 'mobile number']);
    if (nameIndex < 0 || phoneIndex < 0) {
      throw const FormatException('CSV must contain name and phone columns.');
    }
    final db = _ref.read(localDatabaseProvider);
    final shopId = _ref.read(shopIdProvider);
    final existingPhones = db.customers.valuesForShop(shopId)
        .map((item) => _phone(item.phone))
        .where((item) => item.isNotEmpty)
        .toSet();
    var created = 0;
    var skipped = 0;
    final errors = <String>[];
    for (var rowIndex = 1; rowIndex < lines.length; rowIndex++) {
      final cells = _split(lines[rowIndex]);
      final name = _cell(cells, nameIndex).trim();
      final phone = _cell(cells, phoneIndex).trim();
      if (name.isEmpty || phone.isEmpty) {
        errors.add('Row ${rowIndex + 1}: name and phone are required.');
        continue;
      }
      final normalized = _phone(phone);
      if (existingPhones.contains(normalized)) {
        skipped++;
        continue;
      }
      final now = DateTime.now();
      await db.customers.put(Customer(
        customerId: _uuid.v4(),
        name: name,
        phone: phone,
        email: _cell(cells, _index(header, ['email'])),
        address: _cell(cells, _index(header, ['address'])),
        notes: _cell(cells, _index(header, ['notes', 'note'])),
        shopId: shopId,
        updatedAt: now,
        syncStatus: SyncStatus.pending,
      ));
      existingPhones.add(normalized);
      created++;
    }
    return CustomerImportResult(created: created, skipped: skipped, errors: errors);
  }

  int _index(List<String> header, List<String> names) {
    for (final name in names) {
      final index = header.indexOf(name);
      if (index >= 0) return index;
    }
    return -1;
  }

  String _cell(List<String> cells, int index) => index >= 0 && index < cells.length ? cells[index] : '';

  List<String> _split(String line) {
    final result = <String>[];
    var buffer = StringBuffer();
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (quoted && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (char == ',' && !quoted) {
        result.add(buffer.toString());
        buffer = StringBuffer();
      } else {
        buffer.write(char);
      }
    }
    result.add(buffer.toString());
    return result;
  }

  String _phone(String value) => value.replaceAll(RegExp(r'\D'), '');
}
