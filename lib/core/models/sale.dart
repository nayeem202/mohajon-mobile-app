import '../utils/date_time_json.dart';
import 'payment.dart';
import 'invoice_totals.dart';
import 'syncable.dart';

enum PaymentStatus { paid, partial, due }

extension PaymentStatusX on PaymentStatus {
  String get value => name.toUpperCase();

  static PaymentStatus parse(Object? value) {
    final normalized = value.toString().toLowerCase();
    return PaymentStatus.values.firstWhere(
      (status) => status.name == normalized,
      orElse: () => PaymentStatus.due,
    );
  }
}

class SaleItem {
  const SaleItem({
    this.saleItemId = '',
    required this.productId,
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.purchasePrice,
    this.batchAllocations = const [],
  });

  final String saleItemId;
  final String productId;
  final String name;
  final double qty;
  final double unitPrice;
  final double purchasePrice;
  final List<SaleBatchAllocation> batchAllocations;

  double get lineTotal => qty * unitPrice;
  double get profit => qty * (unitPrice - purchasePrice);

  Map<String, dynamic> toJson() => {
    'saleItemId': saleItemId,
    'productId': productId,
    'name': name,
    'qty': qty,
    'unitPrice': unitPrice,
    'purchasePrice': purchasePrice,
    'batchAllocations': batchAllocations.map((item) => item.toJson()).toList(),
  };

  factory SaleItem.fromJson(Map<dynamic, dynamic> json) => SaleItem(
    saleItemId: (json['saleItemId'] ?? json['id'] ?? '') as String,
    productId: json['productId'] as String,
    name: (json['name'] ?? '') as String,
    qty: (json['qty'] as num? ?? 0).toDouble(),
    unitPrice: (json['unitPrice'] as num? ?? 0).toDouble(),
    purchasePrice: (json['purchasePrice'] as num? ?? 0).toDouble(),
    batchAllocations: ((json['batchAllocations'] as List?) ?? const [])
        .map(
          (item) => SaleBatchAllocation.fromJson(
            Map<dynamic, dynamic>.from(item as Map),
          ),
        )
        .toList(),
  );
}

class SaleBatchAllocation {
  const SaleBatchAllocation({required this.batchId, required this.quantity});

  final String batchId;
  final int quantity;

  Map<String, dynamic> toJson() => {'batchId': batchId, 'quantity': quantity};

  factory SaleBatchAllocation.fromJson(Map<dynamic, dynamic> json) =>
      SaleBatchAllocation(
        batchId: (json['batchId'] ?? '') as String,
        quantity: (json['quantity'] as num? ?? 0).toInt(),
      );
}

class Sale with Syncable {
  const Sale({
    required this.saleId,
    required this.customerId,
    required this.items,
    required this.totalAmount,
    required this.paidAmount,
    required this.dueAmount,
    required this.paymentStatus,
    required this.shopId,
    required this.createdAt,
    required this.updatedAt,
    this.invoiceNumber = '',
    this.originalTotalAmount,
    this.initialPaidAmount,
    this.initialPaymentId,
    this.discount = 0,
    this.vatPercent = 0,
    this.charge = 0,
    this.paymentMethod = PaymentMethod.cash,
    this.staffId,
    this.branchId,
    this.discountStaffId,
    this.voidedByStaffId,
    this.voidedAt,
    this.loyaltyPointsRedeemed = 0,
    this.loyaltyPointsEarned = 0,
    this.isDeleted = false,
    this.syncStatus = SyncStatus.pending,
  });

  final String saleId;
  final String invoiceNumber;
  final double? originalTotalAmount;
  final double? initialPaidAmount;
  final String? initialPaymentId;
  final String customerId;
  final List<SaleItem> items;
  final double discount;
  final double vatPercent;
  final double charge;
  final PaymentMethod paymentMethod;
  final String? staffId;
  final String? branchId;
  final String? discountStaffId;
  final String? voidedByStaffId;
  final DateTime? voidedAt;
  final int loyaltyPointsRedeemed;
  final int loyaltyPointsEarned;
  final double totalAmount;
  final double paidAmount;
  final double dueAmount;
  final PaymentStatus paymentStatus;
  @override
  final String shopId;
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  final bool isDeleted;
  @override
  final SyncStatus syncStatus;

  @override
  String get id => saleId;

  InvoiceTotals get invoiceTotals => InvoiceTotals.calculate(
    lineTotals: items.map((item) => item.lineTotal),
    discount: discount,
    vatPercent: vatPercent,
    charge: charge,
  );

  double get profit =>
      items.fold<double>(0, (total, item) => total + item.profit) - discount;

  Sale copyWith({
    List<SaleItem>? items,
    double? totalAmount,
    double? paidAmount,
    double? dueAmount,
    PaymentStatus? paymentStatus,
    PaymentMethod? paymentMethod,
    String? staffId,
    String? branchId,
    String? discountStaffId,
    String? voidedByStaffId,
    DateTime? voidedAt,
    int? loyaltyPointsRedeemed,
    int? loyaltyPointsEarned,
    String? invoiceNumber,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
  }) {
    return Sale(
      saleId: saleId,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      originalTotalAmount: originalTotalAmount,
      initialPaidAmount: initialPaidAmount,
      initialPaymentId: initialPaymentId,
      customerId: customerId,
      items: items ?? this.items,
      discount: discount,
      vatPercent: vatPercent,
      charge: charge,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      dueAmount: dueAmount ?? this.dueAmount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      staffId: staffId ?? this.staffId,
      branchId: branchId ?? this.branchId,
      discountStaffId: discountStaffId ?? this.discountStaffId,
      voidedByStaffId: voidedByStaffId ?? this.voidedByStaffId,
      voidedAt: voidedAt ?? this.voidedAt,
      loyaltyPointsRedeemed:
          loyaltyPointsRedeemed ?? this.loyaltyPointsRedeemed,
      loyaltyPointsEarned: loyaltyPointsEarned ?? this.loyaltyPointsEarned,
      shopId: shopId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'saleId': saleId,
    'invoiceNumber': invoiceNumber,
    'originalTotalAmount': originalTotalAmount,
    'initialPaidAmount': initialPaidAmount,
    'initialPaymentId': initialPaymentId,
    'customerId': customerId,
    'items': items.map((item) => item.toJson()).toList(),
    'discount': discount,
    'vatPercent': vatPercent,
    'charge': charge,
    'totalAmount': totalAmount,
    'paidAmount': paidAmount,
    'dueAmount': dueAmount,
    'paymentStatus': paymentStatus.value,
    'paymentMethod': paymentMethod.value,
    'staffId': staffId,
    'branchId': branchId,
    'discountStaffId': discountStaffId,
    'voidedByStaffId': voidedByStaffId,
    'voidedAt': voidedAt == null ? null : dateToJson(voidedAt!),
    'loyaltyPointsRedeemed': loyaltyPointsRedeemed,
    'loyaltyPointsEarned': loyaltyPointsEarned,
    'shopId': shopId,
    'createdAt': dateToJson(createdAt),
    'updatedAt': dateToJson(updatedAt),
    'isDeleted': isDeleted,
    'syncStatus': syncStatus.value,
  };

  factory Sale.fromJson(Map<dynamic, dynamic> json) => Sale(
    saleId: json['saleId'] as String,
    invoiceNumber: (json['invoiceNumber'] ?? '') as String,
    originalTotalAmount: (json['originalTotalAmount'] as num?)?.toDouble(),
    initialPaidAmount: (json['initialPaidAmount'] as num?)?.toDouble(),
    initialPaymentId: json['initialPaymentId'] as String?,
    customerId: (json['customerId'] ?? '') as String,
    items: ((json['items'] as List?) ?? const [])
        .map(
          (item) => SaleItem.fromJson(Map<dynamic, dynamic>.from(item as Map)),
        )
        .toList(),
    discount: (json['discount'] as num? ?? 0).toDouble(),
    vatPercent: (json['vatPercent'] as num? ?? 0).toDouble(),
    charge: (json['charge'] as num? ?? 0).toDouble(),
    totalAmount: (json['totalAmount'] as num? ?? 0).toDouble(),
    paidAmount: (json['paidAmount'] as num? ?? 0).toDouble(),
    dueAmount: (json['dueAmount'] as num? ?? 0).toDouble(),
    paymentStatus: PaymentStatusX.parse(json['paymentStatus']),
    paymentMethod: PaymentMethodX.parse(json['paymentMethod']),
    staffId: json['staffId'] as String?,
    branchId: json['branchId'] == null
        ? '${(json['shopId'] ?? '') as String}-main'
        : json['branchId'] as String?,
    discountStaffId: json['discountStaffId'] as String?,
    voidedByStaffId: json['voidedByStaffId'] as String?,
    voidedAt: json['voidedAt'] == null ? null : dateFromJson(json['voidedAt']),
    loyaltyPointsRedeemed: (json['loyaltyPointsRedeemed'] as num? ?? 0).toInt(),
    loyaltyPointsEarned: (json['loyaltyPointsEarned'] as num? ?? 0).toInt(),
    shopId: (json['shopId'] ?? '') as String,
    createdAt: dateFromJson(json['createdAt']),
    updatedAt: dateFromJson(json['updatedAt']),
    isDeleted: json['isDeleted'] == true,
    syncStatus: SyncStatusX.parse(json['syncStatus']),
  );
}
