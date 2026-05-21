import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/customer_ledger_entry.dart';
import '../../../core/models/ledger_entry.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/sale.dart';
import '../../../core/models/syncable.dart';

final customersProvider = StreamProvider<List<Customer>>((ref) {
  final shopId = ref.watch(shopIdProvider);
  return ref.watch(localDatabaseProvider).customers.watchForShop(shopId);
});

final salesStreamProvider = StreamProvider<List<Sale>>((ref) {
  final shopId = ref.watch(shopIdProvider);
  return ref.watch(localDatabaseProvider).sales.watchForShop(shopId);
});

final paymentsStreamProvider = StreamProvider<List<Payment>>((ref) {
  final shopId = ref.watch(shopIdProvider);
  return ref.watch(localDatabaseProvider).payments.watchForShop(shopId);
});

final customerLedgerEntriesStreamProvider =
    StreamProvider<List<CustomerLedgerEntry>>((ref) {
  final shopId = ref.watch(shopIdProvider);
  return ref.watch(localDatabaseProvider).customerLedgerEntries.watchForShop(
    shopId,
  );
});

final customerServiceProvider = Provider<CustomerService>((ref) {
  return CustomerService(ref, const Uuid());
});

final customerDueProvider = Provider.family<double, String>((ref, customerId) {
  final sales = (ref.watch(salesStreamProvider).value ?? const <Sale>[])
      .where((sale) => sale.customerId == customerId);
  final payments = (ref.watch(paymentsStreamProvider).value ?? const <Payment>[])
      .where((payment) => payment.customerId == customerId);
  final ledgerEntries =
      (ref.watch(customerLedgerEntriesStreamProvider).value ??
              const <CustomerLedgerEntry>[])
          .where((entry) => entry.customerId == customerId);
  final totalSalesDue = sales.fold<double>(0, (sum, sale) => sum + sale.dueAmount);
  final totalUnlinkedPayments = payments
      .where((payment) => payment.saleId == null)
      .fold<double>(0, (sum, payment) => sum + payment.amount);
  final totalAdjustments = ledgerEntries.fold<double>(
    0,
    (sum, entry) => sum + entry.signedAmount,
  );
  return totalSalesDue - totalUnlinkedPayments + totalAdjustments;
});

final customerLedgerProvider = Provider.family<List<LedgerEntry>, String>((ref, customerId) {
  final sales = (ref.watch(salesStreamProvider).value ?? const <Sale>[])
      .where((sale) => sale.customerId == customerId)
      .toList();
  final payments = (ref.watch(paymentsStreamProvider).value ?? const <Payment>[])
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
            description: 'Sale',
          ),
        ),
    ...sales
        .where(
          (sale) => sale.paidAmount > 0 && !paymentSaleIds.contains(sale.saleId),
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
  }) async {
    final customer = Customer(
      customerId: customerId ?? _uuid.v4(),
      name: name,
      phone: phone,
      shopId: _ref.read(shopIdProvider),
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );
    await _ref.read(localDatabaseProvider).customers.put(customer);
    await _ref.read(syncStateProvider.notifier).syncIfOnline();
    return customer;
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
