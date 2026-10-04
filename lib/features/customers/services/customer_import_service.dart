import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/syncable.dart';

class CustomerImportResult {
  const CustomerImportResult({
    required this.created,
    required this.skipped,
    required this.errors,
  });
  final int created;
  final int skipped;
  final List<String> errors;
}

class CustomerImportRow {
  const CustomerImportRow({required this.name, required this.phone});

  final String name;
  final String phone;
}

class CustomerImportService {
  CustomerImportService(this._ref, this._uuid);
  final WidgetRef _ref;
  final Uuid _uuid;

  Future<CustomerImportResult> importCsv(String csv) async {
    final lines = csv
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) throw const FormatException('CSV is empty.');
    final header = _split(
      lines.first,
    ).map((item) => item.trim().toLowerCase()).toList();
    final nameIndex = _index(header, ['name', 'customer', 'customer name']);
    final phoneIndex = _index(header, ['phone', 'mobile', 'mobile number']);
    if (nameIndex < 0 || phoneIndex < 0) {
      throw const FormatException('CSV must contain name and phone columns.');
    }
    final rows = <CustomerImportRow>[];
    final errors = <String>[];
    for (var rowIndex = 1; rowIndex < lines.length; rowIndex++) {
      final cells = _split(lines[rowIndex]);
      final name = _cell(cells, nameIndex).trim();
      final phone = _cell(cells, phoneIndex).trim();
      if (name.isEmpty || phone.isEmpty) {
        errors.add('Row ${rowIndex + 1}: name and phone are required.');
        continue;
      }
      rows.add(CustomerImportRow(name: name, phone: phone));
    }
    final result = await _importRows(rows);
    return CustomerImportResult(
      created: result.created,
      skipped: result.skipped,
      errors: [...errors, ...result.errors],
    );
  }

  Future<CustomerImportResult> importContacts(
    Iterable<CustomerImportRow> contacts,
  ) => _importRows(contacts.toList());

  Future<CustomerImportResult> _importRows(List<CustomerImportRow> rows) async {
    final db = _ref.read(localDatabaseProvider);
    final shopId = _ref.read(shopIdProvider);
    final existingPhones = db.customers
        .valuesForShop(shopId)
        .map((item) => _phone(item.phone))
        .where((item) => item.isNotEmpty)
        .toSet();
    var created = 0;
    var skipped = 0;
    final errors = <String>[];
    for (final row in rows) {
      final name = row.name.trim();
      final phone = row.phone.trim();
      if (name.isEmpty || phone.isEmpty) {
        errors.add('A contact is missing a name or phone number.');
        continue;
      }
      final normalized = _phone(phone);
      if (normalized.isEmpty || existingPhones.contains(normalized)) {
        skipped++;
        continue;
      }
      await db.customers.put(
        Customer(
          customerId: _uuid.v4(),
          name: name,
          phone: phone,
          shopId: shopId,
          updatedAt: DateTime.now(),
          syncStatus: SyncStatus.pending,
        ),
      );
      existingPhones.add(normalized);
      created++;
    }
    return CustomerImportResult(
      created: created,
      skipped: skipped,
      errors: errors,
    );
  }

  int _index(List<String> header, List<String> names) {
    for (final name in names) {
      final index = header.indexOf(name);
      if (index >= 0) return index;
    }
    return -1;
  }

  String _cell(List<String> cells, int index) =>
      index >= 0 && index < cells.length ? cells[index] : '';

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
