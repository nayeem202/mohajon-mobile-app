class SubscriptionPlan {
  const SubscriptionPlan({
    required this.planCode,
    required this.name,
    required this.description,
    required this.priceBdt,
    required this.durationDays,
    required this.isActive,
    required this.tier,
  });

  final String planCode;
  final String name;
  final String description;
  final double priceBdt;
  final int durationDays;
  final bool isActive;
  final String tier;

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      planCode: (json['planCode'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      priceBdt: double.tryParse((json['price'] ?? '').toString()) ?? 0,
      durationDays: (json['durationDays'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      tier: (json['tier'] ?? 'PRO').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'planCode': planCode,
    'name': name,
    'description': description,
    'price': priceBdt,
    'durationDays': durationDays,
    'isActive': isActive,
    'tier': tier,
  };
}

class SubscriptionPurchase {
  const SubscriptionPurchase({
    required this.paymentId,
    required this.gatewayPaymentId,
    required this.paymentStatus,
    required this.subscriptionId,
    required this.planCode,
    required this.amountBdt,
    required this.bkashUrl,
    required this.merchantInvoiceNumber,
  });

  final String paymentId;
  final String? gatewayPaymentId;
  final String paymentStatus;
  final String subscriptionId;
  final String planCode;
  final double amountBdt;
  final String? bkashUrl;
  final String merchantInvoiceNumber;

  factory SubscriptionPurchase.fromJson(Map<String, dynamic> json) {
    return SubscriptionPurchase(
      paymentId: (json['paymentId'] ?? '').toString(),
      gatewayPaymentId: json['gatewayPaymentId'] as String?,
      paymentStatus: (json['paymentStatus'] ?? '').toString(),
      subscriptionId: (json['subscriptionId'] ?? '').toString(),
      planCode: (json['planCode'] ?? '').toString(),
      amountBdt: double.tryParse((json['amount'] ?? '0').toString()) ?? 0,
      bkashUrl: json['bkashUrl'] as String?,
      merchantInvoiceNumber: (json['merchantInvoiceNumber'] ?? '').toString(),
    );
  }
}

class SubscriptionConfirm {
  const SubscriptionConfirm({
    required this.paymentId,
    required this.paymentStatus,
    required this.subscriptionId,
    required this.subscriptionStatus,
    required this.planCode,
    this.gatewayTransactionId,
    this.startDate,
    this.endDate,
    this.errorMessage,
  });

  final String paymentId;
  final String paymentStatus;
  final String subscriptionId;
  final String subscriptionStatus;
  final String planCode;
  final String? gatewayTransactionId;
  final String? startDate;
  final String? endDate;
  final String? errorMessage;

  bool get isSuccess => paymentStatus == 'SUCCESS';

  factory SubscriptionConfirm.fromJson(Map<String, dynamic> json) {
    return SubscriptionConfirm(
      paymentId: (json['paymentId'] ?? '').toString(),
      paymentStatus: (json['paymentStatus'] ?? '').toString(),
      subscriptionId: (json['subscriptionId'] ?? '').toString(),
      subscriptionStatus: (json['subscriptionStatus'] ?? '').toString(),
      planCode: (json['planCode'] ?? '').toString(),
      gatewayTransactionId: json['gatewayTransactionId'] as String?,
      startDate: json['startDate'] as String?,
      endDate: json['endDate'] as String?,
      errorMessage: json['errorMessage'] as String?,
    );
  }
}

class SubscriptionInfo {
  const SubscriptionInfo({
    required this.hasActive,
    this.subscriptionId,
    this.status,
    this.planCode,
    this.planName,
    this.amountBdt,
    this.startDate,
    this.endDate,
    this.daysRemaining,
    this.isTrial = false,
    this.tier = 'FREE',
    this.hasPremium = false,
  });

  final bool hasActive;
  final String? subscriptionId;
  final String? status;
  final String? planCode;
  final String? planName;
  final double? amountBdt;
  final String? startDate;
  final String? endDate;
  final int? daysRemaining;
  final bool isTrial;
  final String tier;
  final bool hasPremium;

  bool get isActive => hasActive;
  bool get isTrialActive => hasActive && isTrial;
  bool get isFree => tier == 'FREE';
  bool get hasBusiness => tier == 'BUSINESS';

  /// A shop remains usable on Free after a trial or paid period ends.
  bool get isExpired => !hasActive && !isFree;

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) {
    final isActive = json['hasActive'] as bool? ?? false;
    final latest = json['latest'] as Map<String, dynamic>? ?? const {};
    final sub = (isActive || json['tier'] == 'FREE'
            ? json['subscription']
            : latest)
            as Map<String, dynamic>? ??
        const {};
    final plan = sub['plan'] as Map<String, dynamic>? ?? const {};
    return SubscriptionInfo(
      hasActive: isActive,
      subscriptionId: sub['subscriptionId'] as String?,
      status: sub['status'] as String?,
      planCode: sub['planCode'] as String?,
      planName: plan['name'] as String?,
      amountBdt:
          double.tryParse((plan['price'] ?? '').toString()),
      startDate: sub['startDate'] as String?,
      endDate: sub['endDate'] as String?,
      daysRemaining: (json['daysRemaining'] as num?)?.toInt(),
      isTrial: (json['isTrial'] as bool?) ??
          (sub['isTrial'] as bool?) ??
          sub['planCode'] == 'TRIAL',
      tier: (json['tier'] ?? plan['tier'] ?? 'FREE').toString(),
      hasPremium: json['hasPremium'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'hasActive': hasActive,
    'isTrial': isTrial,
    'tier': tier,
    'hasPremium': hasPremium,
    'daysRemaining': daysRemaining,
    'subscription': {
      'subscriptionId': subscriptionId,
      'status': status,
      'planCode': planCode,
      'startDate': startDate,
      'endDate': endDate,
      'plan': {'name': planName, 'price': amountBdt?.toStringAsFixed(2)},
    },
  };
}

class AiCreditStatus {
  const AiCreditStatus({
    required this.monthlyLimit,
    required this.monthlyUsed,
    required this.monthlyRemaining,
    required this.welcomeRemaining,
    required this.remaining,
  });

  final int monthlyLimit;
  final int monthlyUsed;
  final int monthlyRemaining;
  final int welcomeRemaining;
  final int remaining;

  factory AiCreditStatus.fromJson(Map<String, dynamic> json) => AiCreditStatus(
        monthlyLimit: (json['monthlyLimit'] as num?)?.toInt() ?? 0,
        monthlyUsed: (json['monthlyUsed'] as num?)?.toInt() ?? 0,
        monthlyRemaining: (json['monthlyRemaining'] as num?)?.toInt() ?? 0,
        welcomeRemaining: (json['welcomeRemaining'] as num?)?.toInt() ?? 0,
        remaining: (json['remaining'] as num?)?.toInt() ?? 0,
      );
}
