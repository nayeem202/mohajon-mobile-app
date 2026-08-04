import '../../../../core/utils/date_time_json.dart';

class Investment {
  const Investment({
    required this.id,
    required this.title,
    required this.shopId,
    this.description = '',
    required this.categoryId,
    required this.categoryName,
    this.totalInvestment = 0,
    this.profitShareMethod = 'proportional',
    this.notes = '',
    this.createdBy = '',
    required this.createdAt,
    required this.updatedAt,
    this.status = 'active',
    this.roi = 0,
    this.totalProfit = 0,
    this.totalPaid = 0,
    this.outstanding = 0,
  });

  final String id;
  final String title;
  final String shopId;
  final String description;
  final String categoryId;
  final String categoryName;
  final double totalInvestment;
  final String profitShareMethod;
  final String notes;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status;
  final double roi;
  final double totalProfit;
  final double totalPaid;
  final double outstanding;

  Investment copyWith({
    String? id,
    String? title,
    String? shopId,
    String? description,
    String? categoryId,
    String? categoryName,
    double? totalInvestment,
    String? profitShareMethod,
    String? notes,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
    double? roi,
    double? totalProfit,
    double? totalPaid,
    double? outstanding,
  }) {
    return Investment(
      id: id ?? this.id,
      title: title ?? this.title,
      shopId: shopId ?? this.shopId,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      totalInvestment: totalInvestment ?? this.totalInvestment,
      profitShareMethod: profitShareMethod ?? this.profitShareMethod,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      roi: roi ?? this.roi,
      totalProfit: totalProfit ?? this.totalProfit,
      totalPaid: totalPaid ?? this.totalPaid,
      outstanding: outstanding ?? this.outstanding,
    );
  }

  Map<String, dynamic> toJson() => {
    'investmentId': id,
    'title': title,
    'shopId': shopId,
    'description': description,
    'categoryId': categoryId,
    'categoryName': categoryName,
    'totalInvestment': totalInvestment,
    'profitShareMethod': profitShareMethod,
    'notes': notes,
    'createdBy': createdBy,
    'createdAt': dateToJson(createdAt),
    'updatedAt': dateToJson(updatedAt),
    'status': status,
    'roi': roi,
    'totalProfit': totalProfit,
    'totalPaid': totalPaid,
    'outstanding': outstanding,
  };

  factory Investment.fromJson(String id, Map<String, dynamic> json) {
    return Investment(
      id: (json['investmentId'] as String?)?.isNotEmpty == true
          ? json['investmentId'] as String
          : id,
      title: json['title'] as String? ?? '',
      shopId: json['shopId'] as String? ?? '',
      description: json['description'] as String? ?? '',
      categoryId: json['categoryId'] as String? ?? '',
      categoryName: json['categoryName'] as String? ?? '',
      totalInvestment: (json['totalInvestment'] as num?)?.toDouble() ?? 0,
      profitShareMethod: json['profitShareMethod'] as String? ?? 'proportional',
      notes: json['notes'] as String? ?? '',
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: dateFromJson(json['createdAt']),
      updatedAt: dateFromJson(json['updatedAt']),
      status: (json['status'] as String? ?? 'active').toLowerCase(),
      roi: (json['roi'] as num?)?.toDouble() ?? 0,
      totalProfit: (json['totalProfit'] as num?)?.toDouble() ?? 0,
      totalPaid: (json['totalPaid'] as num?)?.toDouble() ?? 0,
      outstanding: (json['outstanding'] as num?)?.toDouble() ?? 0,
    );
  }
}
