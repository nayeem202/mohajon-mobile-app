import '../../../core/models/syncable.dart';
import '../../../core/utils/date_time_json.dart';

class Expense with Syncable {
  const Expense({
    required this.expenseId,
    required this.description,
    required this.amount,
    required this.categoryId,
    required this.categoryLabel,
    required this.date,
    this.notes = '',
    required this.shopId,
    required this.updatedAt,
    this.isDeleted = false,
    this.syncStatus = SyncStatus.pending,
  });

  final String expenseId;
  final String description;
  final double amount;
  final String categoryId;
  final String categoryLabel;
  final DateTime date;
  final String notes;
  @override
  final String shopId;
  @override
  final DateTime updatedAt;
  final bool isDeleted;
  @override
  final SyncStatus syncStatus;

  @override
  String get id => expenseId;

  Expense copyWith({
    String? expenseId,
    String? description,
    double? amount,
    String? categoryId,
    String? categoryLabel,
    DateTime? date,
    String? notes,
    String? shopId,
    DateTime? updatedAt,
    bool? isDeleted,
    SyncStatus? syncStatus,
  }) {
    return Expense(
      expenseId: expenseId ?? this.expenseId,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      categoryLabel: categoryLabel ?? this.categoryLabel,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      shopId: shopId ?? this.shopId,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'expenseId': expenseId,
        'description': description,
        'amount': amount,
        'categoryId': categoryId,
        'categoryLabel': categoryLabel,
        'date': dateToJson(date),
        'notes': notes,
        'shopId': shopId,
        'updatedAt': dateToJson(updatedAt),
        'isDeleted': isDeleted,
        'syncStatus': syncStatus.value,
      };

  factory Expense.fromJson(Map<dynamic, dynamic> json) => Expense(
        expenseId: json['expenseId'] as String,
        description: (json['description'] ?? '') as String,
        amount: (json['amount'] as num? ?? 0).toDouble(),
        categoryId: (json['categoryId'] ?? '') as String,
        categoryLabel: (json['categoryLabel'] ?? '') as String,
        date: dateFromJson(json['date']),
        notes: (json['notes'] ?? '') as String,
        shopId: (json['shopId'] ?? '') as String,
        updatedAt: dateFromJson(json['updatedAt']),
        isDeleted: json['isDeleted'] == true,
        syncStatus: SyncStatusX.parse(json['syncStatus']),
      );
}

