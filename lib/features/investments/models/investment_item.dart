import '../../../core/utils/date_time_json.dart';
import '../../../core/models/syncable.dart';

class InvestmentItem with Syncable {
  const InvestmentItem({
    required this.investmentId,
    required this.title,
    this.description = '',
    required this.category,
    this.investorName = '',
    required this.amount,
    this.returnAmount = 0.0,
    this.outstandingAmount = 0.0,
    this.notes = '',
    this.status = 'active',
    required this.date,
    required this.shopId,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.syncStatus = SyncStatus.pending,
  });

  final String investmentId;
  final String title;
  final String description;
  final String category;
  final String investorName;
  final double amount;
  final double returnAmount;
  final double outstandingAmount;
  final String notes;
  final String status;
  final DateTime date;
  final DateTime createdAt;
  @override
  final String shopId;
  @override
  final DateTime updatedAt;
  final bool isDeleted;
  @override
  final SyncStatus syncStatus;

  @override
  String get id => investmentId;

  double get roi {
    if (amount <= 0) return 0;
    return ((returnAmount - amount) / amount) * 100;
  }

  InvestmentItem copyWith({
    String? investmentId,
    String? title,
    String? description,
    String? category,
    String? investorName,
    double? amount,
    double? returnAmount,
    double? outstandingAmount,
    String? notes,
    String? status,
    DateTime? date,
    DateTime? createdAt,
    String? shopId,
    DateTime? updatedAt,
    bool? isDeleted,
    SyncStatus? syncStatus,
  }) {
    return InvestmentItem(
      investmentId: investmentId ?? this.investmentId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      investorName: investorName ?? this.investorName,
      amount: amount ?? this.amount,
      returnAmount: returnAmount ?? this.returnAmount,
      outstandingAmount: outstandingAmount ?? this.outstandingAmount,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      shopId: shopId ?? this.shopId,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'investmentId': investmentId,
    'title': title,
    'description': description,
    'category': category,
    'investorName': investorName,
    'amount': amount,
    'returnAmount': returnAmount,
    'outstandingAmount': outstandingAmount,
    'notes': notes,
    'status': status,
    'date': dateToJson(date),
    'createdAt': dateToJson(createdAt),
    'shopId': shopId,
    'updatedAt': dateToJson(updatedAt),
    'isDeleted': isDeleted,
    'syncStatus': syncStatus.value,
  };

  factory InvestmentItem.fromJson(Map<dynamic, dynamic> json) => InvestmentItem(
    investmentId: json['investmentId'] as String,
    title: (json['title'] ?? '') as String,
    description: (json['description'] ?? '') as String,
    category: (json['category'] ?? 'Other') as String,
    investorName: (json['investorName'] ?? '') as String,
    amount: (json['amount'] as num? ?? 0).toDouble(),
    returnAmount: (json['returnAmount'] as num? ?? 0).toDouble(),
    outstandingAmount: (json['outstandingAmount'] as num? ?? 0).toDouble(),
    notes: (json['notes'] ?? '') as String,
    status: (json['status'] ?? 'active') as String,
    date: dateFromJson(json['date']),
    createdAt: dateFromJson(json['createdAt']),
    shopId: (json['shopId'] ?? '') as String,
    updatedAt: dateFromJson(json['updatedAt']),
    isDeleted: json['isDeleted'] == true,
    syncStatus: SyncStatusX.parse(json['syncStatus']),
  );
}
