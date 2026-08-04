import '../../../../core/utils/date_time_json.dart';

class Payout {
  const Payout({
    required this.id,
    required this.investmentId,
    required this.investorId,
    required this.amount,
    required this.shopId,
    this.note = '',
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String investmentId;
  final String investorId;
  final double amount;
  final String shopId;
  final String note;
  final String createdBy;
  final DateTime createdAt;

  Payout copyWith({
    String? id,
    String? investmentId,
    String? investorId,
    double? amount,
    String? shopId,
    String? note,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return Payout(
      id: id ?? this.id,
      investmentId: investmentId ?? this.investmentId,
      investorId: investorId ?? this.investorId,
      amount: amount ?? this.amount,
      shopId: shopId ?? this.shopId,
      note: note ?? this.note,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'payoutId': id,
    'investmentId': investmentId,
    'investorId': investorId,
    'amount': amount,
    'shopId': shopId,
    'note': note,
    'createdBy': createdBy,
    'createdAt': dateToJson(createdAt),
  };

  factory Payout.fromJson(String id, Map<String, dynamic> json) {
    return Payout(
      id: (json['payoutId'] as String?)?.isNotEmpty == true
          ? json['payoutId'] as String
          : id,
      investmentId: json['investmentId'] as String? ?? '',
      investorId: json['investorId'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      shopId: json['shopId'] as String? ?? '',
      note: json['note'] as String? ?? '',
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: dateFromJson(json['createdAt']),
    );
  }
}
