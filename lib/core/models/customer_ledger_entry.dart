import '../utils/date_time_json.dart';
import 'syncable.dart';

enum CustomerLedgerEntryType { debit, credit }

extension CustomerLedgerEntryTypeX on CustomerLedgerEntryType {
  String get value => name.toUpperCase();

  static CustomerLedgerEntryType parse(Object? value) {
    final normalized = value.toString().toLowerCase();
    return CustomerLedgerEntryType.values.firstWhere(
      (type) => type.name == normalized,
      orElse: () => CustomerLedgerEntryType.debit,
    );
  }
}

class CustomerLedgerEntry with Syncable {
  const CustomerLedgerEntry({
    required this.entryId,
    required this.customerId,
    required this.type,
    required this.amount,
    required this.note,
    required this.shopId,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.syncStatus = SyncStatus.pending,
  });

  final String entryId;
  final String customerId;
  final CustomerLedgerEntryType type;
  final double amount;
  final String note;
  @override
  final String shopId;
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  final bool isDeleted;
  @override
  final SyncStatus syncStatus;

  @override
  String get id => entryId;

  double get signedAmount =>
      type == CustomerLedgerEntryType.debit ? amount : -amount;

  @override
  Map<String, dynamic> toJson() => {
    'entryId': entryId,
    'customerId': customerId,
    'type': type.value,
    'amount': amount,
    'note': note,
    'shopId': shopId,
    'createdAt': dateToJson(createdAt),
    'updatedAt': dateToJson(updatedAt),
    'isDeleted': isDeleted,
    'syncStatus': syncStatus.value,
  };

  factory CustomerLedgerEntry.fromJson(Map<dynamic, dynamic> json) =>
      CustomerLedgerEntry(
        entryId: json['entryId'] as String,
        customerId: (json['customerId'] ?? '') as String,
        type: CustomerLedgerEntryTypeX.parse(json['type']),
        amount: (json['amount'] as num? ?? 0).toDouble(),
        note: (json['note'] ?? '') as String,
        shopId: (json['shopId'] ?? '') as String,
        createdAt: dateFromJson(json['createdAt']),
        updatedAt: dateFromJson(json['updatedAt']),
        isDeleted: json['isDeleted'] == true,
        syncStatus: SyncStatusX.parse(json['syncStatus']),
      );
}
