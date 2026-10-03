import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/customer_ledger_entry.dart';
import '../../../core/models/ledger_entry.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/sale.dart';
import '../../../core/models/syncable.dart';
import '../../../core/services/file_upload_service.dart';
import '../../../core/services/api_client.dart';
import '../../../core/offline/local_database.dart';
import '../../branches/providers/branch_providers.dart';

final customersProvider = StreamProvider<List<Customer>>((ref) {
  final shopId = ref.watch(shopIdProvider);
  return ref.watch(localDatabaseProvider).customers.watchForShop(shopId);
});

final customerSearchQueryProvider = StateProvider.autoDispose<String>(
  (ref) => '',
);

final filteredCustomersProvider = Provider<List<Customer>>((ref) {
  final customers = ref.watch(customersProvider).value ?? const <Customer>[];
  final query = ref.watch(customerSearchQueryProvider).trim().toLowerCase();
  if (query.isEmpty) return customers;

  return customers.where((customer) {
    return customer.name.toLowerCase().contains(query) ||
        customer.phone.toLowerCase().contains(query);
  }).toList();
});

final salesStreamProvider = StreamProvider<List<Sale>>((ref) {
  final shopId = ref.watch(shopIdProvider);
  final branchId = ref.watch(currentBranchIdProvider) ?? '$shopId-main';
  return ref.watch(localDatabaseProvider).sales.watchForShop(shopId).map(
        (sales) => sales.where((sale) => sale.branchId == null || sale.branchId == branchId).toList(),
      );
});

final paymentsStreamProvider = StreamProvider<List<Payment>>((ref) {
  final shopId = ref.watch(shopIdProvider);
  final branchId = ref.watch(currentBranchIdProvider) ?? '$shopId-main';
  return ref.watch(localDatabaseProvider).payments.watchForShop(shopId).map(
        (payments) => payments.where((payment) => payment.branchId == null || payment.branchId == branchId).toList(),
      );
});

final customerLedgerEntriesStreamProvider =
    StreamProvider<List<CustomerLedgerEntry>>((ref) {
      final shopId = ref.watch(shopIdProvider);
      return ref
          .watch(localDatabaseProvider)
          .customerLedgerEntries
          .watchForShop(shopId);
    });

final customerServiceProvider = Provider<CustomerService>((ref) {
  return CustomerService(ref, const Uuid());
});

final customerTagProvider = Provider.family<String, String>((ref, customerId) {
  final customer = (ref.watch(customersProvider).value ?? [])
      .where((c) => c.customerId == customerId)
      .firstOrNull;
  if (customer == null) return '';
  final settings = ref.read(localDatabaseProvider).settings;
  final vipThreshold = (settings.get('customerVipThreshold') as num? ?? 10000).toDouble();
  final regularThreshold = (settings.get('customerRegularThreshold') as num? ?? 1000).toDouble();

  final sales = (ref.watch(salesStreamProvider).value ?? [])
      .where((s) => s.customerId == customerId);
  final totalSpent = sales.fold<double>(0, (s, sale) => s + sale.totalAmount);

  if (totalSpent >= vipThreshold) return 'VIP';
  if (totalSpent >= regularThreshold) return 'Regular';
  return '';
});

class LoyaltyOfferConfig {
  const LoyaltyOfferConfig({
    required this.enabled,
    required this.pointsRequired,
    required this.discountPercent,
    required this.maxDiscount,
    required this.minimumPurchase,
  });

  final bool enabled;
  final int pointsRequired;
  final double discountPercent;
  final double maxDiscount;
  final double minimumPurchase;

  static LoyaltyOfferConfig fromSettings(dynamic settings) => LoyaltyOfferConfig(
        enabled: settings.get('loyaltyOfferEnabled', defaultValue: true) as bool,
        pointsRequired: (settings.get('loyaltyOfferPoints', defaultValue: 100) as num).toInt().clamp(1, 1000000),
        discountPercent: (settings.get('loyaltyOfferPercent', defaultValue: 5) as num).toDouble().clamp(0, 100),
        maxDiscount: (settings.get('loyaltyOfferMaxDiscount', defaultValue: 100) as num).toDouble().clamp(0, double.infinity),
        minimumPurchase: (settings.get('loyaltyOfferMinimumPurchase', defaultValue: 0) as num).toDouble().clamp(0, double.infinity),
      );
}

final loyaltyOfferProvider = Provider<LoyaltyOfferConfig>((ref) {
  return LoyaltyOfferConfig.fromSettings(ref.watch(localDatabaseProvider).settings);
});

class LoyaltySummary {
  const LoyaltySummary({required this.points, required this.tier, required this.nextRewardPoints, required this.pointsRequired});

  final int points;
  final String tier;
  final int nextRewardPoints;
  final int pointsRequired;

  bool get rewardReady => points >= pointsRequired;
}

final customerLoyaltyProvider = Provider.family<LoyaltySummary, String>((ref, customerId) {
  final offer = ref.watch(loyaltyOfferProvider);
  final customer = (ref.watch(customersProvider).value ?? const <Customer>[])
      .where((item) => item.customerId == customerId)
      .firstOrNull;
  final points = customer?.loyaltyPoints ?? 0;
  final tier = points >= 500
      ? 'Gold'
      : points >= 200
          ? 'Silver'
          : 'Member';
  return LoyaltySummary(
    points: points,
    tier: tier,
    nextRewardPoints: points >= offer.pointsRequired ? 0 : offer.pointsRequired - points,
    pointsRequired: offer.pointsRequired,
  );
});

final customerDueProvider = Provider.family<double, String>((ref, customerId) {
  final sales = (ref.watch(salesStreamProvider).value ?? const <Sale>[]).where(
    (sale) => sale.customerId == customerId,
  );
  final payments =
      (ref.watch(paymentsStreamProvider).value ?? const <Payment>[]).where(
        (payment) => payment.customerId == customerId,
      );
  final ledgerEntries =
      (ref.watch(customerLedgerEntriesStreamProvider).value ??
              const <CustomerLedgerEntry>[])
          .where((entry) => entry.customerId == customerId);
  final totalSalesDue = sales.fold<double>(
    0,
    (sum, sale) => sum + sale.dueAmount,
  );
  final totalUnlinkedPayments = payments
      .where((payment) => payment.saleId == null)
      .fold<double>(0, (sum, payment) => sum + payment.amount);
  final totalAdjustments = ledgerEntries.fold<double>(
    0,
    (sum, entry) => sum + entry.signedAmount,
  );
  return totalSalesDue - totalUnlinkedPayments + totalAdjustments;
});

final customerLedgerProvider = Provider.family<List<LedgerEntry>, String>((
  ref,
  customerId,
) {
  final sales = (ref.watch(salesStreamProvider).value ?? const <Sale>[])
      .where((sale) => sale.customerId == customerId)
      .toList();
  final payments =
      (ref.watch(paymentsStreamProvider).value ?? const <Payment>[])
          .where((payment) => payment.customerId == customerId)
          .toList();
  final paymentSaleIds = payments
      .where((payment) => payment.saleId != null)
      .map((payment) => payment.saleId)
      .toSet();
  final entries = <LedgerEntry>[
    ...sales.map(
      (sale) => LedgerEntry(
        id: sale.saleId,
        type: LedgerEntryType.sale,
        amount: sale.totalAmount,
        createdAt: sale.createdAt,
        description: _saleParticulars(sale),
      ),
    ),
    ...sales
        .where(
          (sale) =>
              sale.paidAmount > 0 && !paymentSaleIds.contains(sale.saleId),
        )
        .map(
          (sale) => LedgerEntry(
            id: '${sale.saleId}:paid',
            type: LedgerEntryType.payment,
            amount: sale.paidAmount,
            createdAt: sale.createdAt.add(const Duration(milliseconds: 1)),
            description: 'CASH',
          ),
        ),
    ...payments.map(
      (payment) => LedgerEntry(
        id: payment.paymentId,
        type: LedgerEntryType.payment,
        amount: payment.amount,
        createdAt: payment.createdAt,
        description: payment.paymentMethod.value,
      ),
    ),
    ...(ref.watch(customerLedgerEntriesStreamProvider).value ??
            const <CustomerLedgerEntry>[])
        .where((entry) => entry.customerId == customerId)
        .map(
          (entry) => LedgerEntry(
            id: entry.id,
            type: entry.type == CustomerLedgerEntryType.debit
                ? LedgerEntryType.debit
                : LedgerEntryType.credit,
            amount: entry.amount,
            createdAt: entry.createdAt,
            description: entry.note.isEmpty
                ? (entry.type == CustomerLedgerEntryType.debit
                      ? 'Debit'
                      : 'Credit')
                : entry.note,
          ),
        ),
  ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return entries;
});

final customerLedgerServiceProvider = Provider<CustomerLedgerService>((ref) {
  return CustomerLedgerService(ref, const Uuid());
});

class CustomerService {
  CustomerService(this._ref, this._uuid);

  final Ref _ref;
  final Uuid _uuid;

  Future<Customer> save({
    String? customerId,
    required String name,
    required String phone,
    String email = '',
    String address = '',
    String notes = '',
    String? imagePath,
    double creditLimit = 0,
  }) async {
    final shopId = _ref.read(shopIdProvider);
    final existing = customerId == null
        ? null
        : _ref.read(localDatabaseProvider).customers.getForShop(shopId, customerId);
    final customer = Customer(
      customerId: customerId ?? _uuid.v4(),
      name: name,
      phone: phone,
      email: email,
      address: address,
      notes: notes,
      creditLimit: creditLimit,
      totalSpent: existing?.totalSpent ?? 0,
      loyaltyPoints: existing?.loyaltyPoints ?? 0,
      tag: existing?.tag ?? '',
      imagePath: await FileUploadService(
        _ref.read(localDatabaseProvider),
      ).uploadIfNeeded(imagePath),
      shopId: shopId,
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );
    await _ref.read(localDatabaseProvider).customers.put(customer);
    await _ref.read(syncStateProvider.notifier).syncIfOnline();
    return customer;
  }

  /// Merges [duplicateId] into [primaryId] without deleting any financial row.
  ///
  /// Every affected sale/payment/ledger row is re-linked and marked pending;
  /// the duplicate customer itself is soft-deleted only after all references
  /// are persisted. If a later sync fails, the local records remain recoverable.
  Future<void> mergeCustomers({
    required String primaryId,
    required String duplicateId,
  }) async {
    if (primaryId == duplicateId) return;
    final db = _ref.read(localDatabaseProvider);
    final shopId = _ref.read(shopIdProvider);
    final primary = db.customers.getForShop(shopId, primaryId);
    final duplicate = db.customers.getForShop(shopId, duplicateId);
    if (primary == null || duplicate == null || duplicate.isDeleted) {
      throw StateError('Customer merge source is no longer available.');
    }

    Future<void> relink(
      Iterable<dynamic> rows,
      dynamic collection,
      String key,
    ) async {
      for (final row in rows) {
        if (row.isDeleted || row.customerId != duplicateId) continue;
        final json = Map<String, dynamic>.from(row.toJson())
          ..['customerId'] = primaryId
          ..['updatedAt'] = DateTime.now().toIso8601String();
        await collection.putRawPending(shopId, row.id, json);
      }
    }

    await relink(db.sales.valuesForShop(shopId, includeDeleted: true), db.sales, 'sales');
    await relink(db.payments.valuesForShop(shopId, includeDeleted: true), db.payments, 'payments');
    await relink(
      db.customerLedgerEntries.valuesForShop(shopId, includeDeleted: true),
      db.customerLedgerEntries,
      'customerLedgerEntries',
    );

    final primaryJson = Map<String, dynamic>.from(primary.toJson())
      ..['totalSpent'] = primary.totalSpent + duplicate.totalSpent
      ..['loyaltyPoints'] = primary.loyaltyPoints + duplicate.loyaltyPoints
      ..['updatedAt'] = DateTime.now().toIso8601String();
    await db.customers.putRawPending(shopId, primaryId, primaryJson);

    final duplicateJson = Map<String, dynamic>.from(duplicate.toJson())
      ..['isDeleted'] = true
      ..['updatedAt'] = DateTime.now().toIso8601String();
    await db.customers.putRawPending(shopId, duplicateId, duplicateJson);
    await _mergeLocalDueRecovery(db, shopId, primaryId, duplicateId);
    try {
      await ApiClient(db).post('/api/v1/customers/merge', {
        'primaryId': primaryId,
        'duplicateId': duplicateId,
      });
    } on ApiException {
      await _queueCustomerMerge(db, shopId, primaryId, duplicateId);
    } catch (_) {
      await _queueCustomerMerge(db, shopId, primaryId, duplicateId);
    }
    await _ref.read(syncStateProvider.notifier).syncIfOnline();
  }

  Future<void> _queueCustomerMerge(
    LocalDatabase db,
    String shopId,
    String primaryId,
    String duplicateId,
  ) async {
    final key = 'customerMerge.$shopId.$primaryId.$duplicateId';
    await db.settings.put(key, {
      'primaryId': primaryId,
      'duplicateId': duplicateId,
      'queuedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _mergeLocalDueRecovery(
    LocalDatabase db,
    String shopId,
    String primaryId,
    String duplicateId,
  ) async {
    final primaryKey = 'dueRecovery.$shopId.$primaryId';
    final duplicateKey = 'dueRecovery.$shopId.$duplicateId';
    final primaryRaw = db.settings.get(primaryKey);
    final duplicateRaw = db.settings.get(duplicateKey);
    if (duplicateRaw is! Map) return;
    final primary = primaryRaw is Map
        ? Map<String, dynamic>.from(primaryRaw)
        : <String, dynamic>{};
    final duplicate = Map<String, dynamic>.from(duplicateRaw);
    if (primary['promisedPaymentDate'] == null) {
      primary['promisedPaymentDate'] = duplicate['promisedPaymentDate'];
    }
    if (primary['snoozedUntil'] == null) {
      primary['snoozedUntil'] = duplicate['snoozedUntil'];
    }
    final merged = <String, Map<String, dynamic>>{};
    for (final source in [primary['followUps'], duplicate['followUps']]) {
      if (source is! List) continue;
      for (final raw in source.whereType<Map>()) {
        final item = Map<String, dynamic>.from(raw);
        final id = (item['id'] ?? '').toString();
        if (id.isNotEmpty) merged[id] = item;
      }
    }
    primary['followUps'] = merged.values.toList()
      ..sort((a, b) => '${b['createdAt'] ?? ''}'.compareTo('${a['createdAt'] ?? ''}'));
    primary['updatedAt'] = DateTime.now().toIso8601String();
    await db.settings.put(primaryKey, primary);
    await db.settings.delete(duplicateKey);
  }
}

class CustomerLedgerService {
  CustomerLedgerService(this._ref, this._uuid);

  final Ref _ref;
  final Uuid _uuid;

  Future<void> addDebit({
    required String customerId,
    required double amount,
    String note = '',
  }) {
    return _save(
      customerId: customerId,
      type: CustomerLedgerEntryType.debit,
      amount: amount,
      note: note,
    );
  }

  Future<void> addCredit({
    required String customerId,
    required double amount,
    String note = '',
  }) {
    return _save(
      customerId: customerId,
      type: CustomerLedgerEntryType.credit,
      amount: amount,
      note: note,
    );
  }

  Future<void> _save({
    required String customerId,
    required CustomerLedgerEntryType type,
    required double amount,
    required String note,
  }) async {
    final now = DateTime.now();
    final entry = CustomerLedgerEntry(
      entryId: _uuid.v4(),
      customerId: customerId,
      type: type,
      amount: amount,
      note: note.trim(),
      shopId: _ref.read(shopIdProvider),
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.pending,
    );
    await _ref.read(localDatabaseProvider).customerLedgerEntries.put(entry);
    await _ref.read(syncStateProvider.notifier).syncIfOnline();
  }
}

String _saleParticulars(Sale sale) {
  final parts = sale.items.map((item) {
    final qty = item.qty % 1 == 0
        ? item.qty.toInt().toString()
        : item.qty.toString();
    return '${item.name} ×$qty';
  }).join(', ');
  return parts.length <= 60 ? parts : '${parts.substring(0, 57)}...';
}
