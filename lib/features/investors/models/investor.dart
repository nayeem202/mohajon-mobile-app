import 'package:cloud_firestore/cloud_firestore.dart';

class Investor {
  const Investor({
    required this.id,
    required this.name,
    required this.shopId,
    this.phone = '',
    this.email = '',
    this.address = '',
    this.photoUrl = '',
    this.notes = '',
    this.totalInvestment = 0,
    this.totalProfit = 0,
    this.totalLoss = 0,
    this.outstanding = 0,
    this.investmentCount = 0,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String shopId;
  final String phone;
  final String email;
  final String address;
  final String photoUrl;
  final String notes;
  final double totalInvestment;
  final double totalProfit;
  final double totalLoss;
  final double outstanding;
  final int investmentCount;
  final DateTime createdAt;

  Investor copyWith({
    String? id,
    String? name,
    String? shopId,
    String? phone,
    String? email,
    String? address,
    String? photoUrl,
    String? notes,
    double? totalInvestment,
    double? totalProfit,
    double? totalLoss,
    double? outstanding,
    int? investmentCount,
    DateTime? createdAt,
  }) {
    return Investor(
      id: id ?? this.id,
      name: name ?? this.name,
      shopId: shopId ?? this.shopId,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      photoUrl: photoUrl ?? this.photoUrl,
      notes: notes ?? this.notes,
      totalInvestment: totalInvestment ?? this.totalInvestment,
      totalProfit: totalProfit ?? this.totalProfit,
      totalLoss: totalLoss ?? this.totalLoss,
      outstanding: outstanding ?? this.outstanding,
      investmentCount: investmentCount ?? this.investmentCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'shopId': shopId,
    'phone': phone,
    'email': email,
    'address': address,
    'photoUrl': photoUrl,
    'notes': notes,
    'totalInvestment': totalInvestment,
    'totalProfit': totalProfit,
    'totalLoss': totalLoss,
    'outstanding': outstanding,
    'investmentCount': investmentCount,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  factory Investor.fromJson(String id, Map<String, dynamic> json) {
    return Investor(
      id: id,
      name: json['name'] as String? ?? '',
      shopId: json['shopId'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      address: json['address'] as String? ?? '',
      photoUrl: json['photoUrl'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      totalInvestment: (json['totalInvestment'] as num?)?.toDouble() ?? 0,
      totalProfit: (json['totalProfit'] as num?)?.toDouble() ?? 0,
      totalLoss: (json['totalLoss'] as num?)?.toDouble() ?? 0,
      outstanding: (json['outstanding'] as num?)?.toDouble() ?? 0,
      investmentCount: (json['investmentCount'] as num?)?.toInt() ?? 0,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
