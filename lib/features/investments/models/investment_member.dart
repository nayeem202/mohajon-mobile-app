class InvestmentMember {
  const InvestmentMember({
    required this.id,
    required this.investmentId,
    required this.investorId,
    required this.investmentAmount,
    required this.shopId,
    this.sharePercentage = 0,
    this.profit = 0,
    this.loss = 0,
    this.paidAmount = 0,
    this.remainingAmount = 0,
  });

  final String id;
  final String investmentId;
  final String investorId;
  final double investmentAmount;
  final String shopId;
  final double sharePercentage;
  final double profit;
  final double loss;
  final double paidAmount;
  final double remainingAmount;

  InvestmentMember copyWith({
    String? id,
    String? investmentId,
    String? investorId,
    double? investmentAmount,
    String? shopId,
    double? sharePercentage,
    double? profit,
    double? loss,
    double? paidAmount,
    double? remainingAmount,
  }) {
    return InvestmentMember(
      id: id ?? this.id,
      investmentId: investmentId ?? this.investmentId,
      investorId: investorId ?? this.investorId,
      investmentAmount: investmentAmount ?? this.investmentAmount,
      shopId: shopId ?? this.shopId,
      sharePercentage: sharePercentage ?? this.sharePercentage,
      profit: profit ?? this.profit,
      loss: loss ?? this.loss,
      paidAmount: paidAmount ?? this.paidAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
    );
  }

  Map<String, dynamic> toJson() => {
    'investmentId': investmentId,
    'investorId': investorId,
    'investmentAmount': investmentAmount,
    'shopId': shopId,
    'sharePercentage': sharePercentage,
    'profit': profit,
    'loss': loss,
    'paidAmount': paidAmount,
    'remainingAmount': remainingAmount,
  };

  factory InvestmentMember.fromJson(String id, Map<String, dynamic> json) {
    return InvestmentMember(
      id: (json['id'] as String?)?.isNotEmpty == true
          ? json['id'] as String
          : '${json['investmentId']}:${json['investorId']}',
      investmentId: json['investmentId'] as String? ?? '',
      investorId: json['investorId'] as String? ?? '',
      investmentAmount: (json['investmentAmount'] as num?)?.toDouble() ?? 0,
      shopId: json['shopId'] as String? ?? '',
      sharePercentage: (json['sharePercentage'] as num?)?.toDouble() ?? 0,
      profit: (json['profit'] as num?)?.toDouble() ?? 0,
      loss: (json['loss'] as num?)?.toDouble() ?? 0,
      paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0,
      remainingAmount: (json['remainingAmount'] as num?)?.toDouble() ?? 0,
    );
  }
}
