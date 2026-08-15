import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/models/syncable.dart';
import '../models/vendor.dart';
import '../models/vendor_payment.dart';
import '../models/vendor_purchase.dart';
import '../../notifications/models/notification_model.dart';
import '../../notifications/providers/notification_providers.dart';

final vendorsProvider = StreamProvider<List<Vendor>>((ref) {
  final shopId = ref.watch(shopIdProvider);
  return ref.watch(localDatabaseProvider).vendors.watchForShop(shopId);
});

final vendorSearchQueryProvider = StateProvider.autoDispose<String>(
  (ref) => '',
);

final vendorCategoryFilterProvider = StateProvider<String>((ref) => '');

final vendorSortProvider = StateProvider<VendorSort>((ref) => VendorSort.newest);

enum VendorSort { newest, oldest, highestDue, lowestDue, mostOrders, highestPurchase, alphabetical }

final filteredVendorsProvider = Provider<List<Vendor>>((ref) {
  final vendors = ref.watch(vendorsProvider).value ?? const <Vendor>[];
  final query = ref.watch(vendorSearchQueryProvider).trim().toLowerCase();
  final category = ref.watch(vendorCategoryFilterProvider);
  final sort = ref.watch(vendorSortProvider);

  var filtered = vendors;

  if (query.isNotEmpty) {
    filtered = filtered.where((v) {
      return v.companyName.toLowerCase().contains(query) ||
          v.contactPerson.toLowerCase().contains(query) ||
          v.phone.toLowerCase().contains(query) ||
          v.category.toLowerCase().contains(query) ||
          v.products.toLowerCase().contains(query);
    }).toList();
  }

  if (category.isNotEmpty) {
    filtered = filtered.where((v) => v.category == category).toList();
  }

  filtered = [...filtered]..sort((a, b) {
    return switch (sort) {
      VendorSort.newest => b.updatedAt.compareTo(a.updatedAt),
      VendorSort.oldest => a.updatedAt.compareTo(b.updatedAt),
      VendorSort.highestDue => b.pendingAmount.compareTo(a.pendingAmount),
      VendorSort.lowestDue => a.pendingAmount.compareTo(b.pendingAmount),
      VendorSort.mostOrders => b.totalOrders.compareTo(a.totalOrders),
      VendorSort.highestPurchase => b.totalSpent.compareTo(a.totalSpent),
      VendorSort.alphabetical => a.companyName.toLowerCase().compareTo(b.companyName.toLowerCase()),
    };
  });

  return filtered;
});

final vendorPurchasesProvider = StreamProvider<List<VendorPurchase>>((ref) {
  final shopId = ref.watch(shopIdProvider);
  return ref.watch(localDatabaseProvider).vendorPurchases.watchForShop(shopId);
});

final vendorPaymentsProvider = StreamProvider<List<VendorPayment>>((ref) {
  final shopId = ref.watch(shopIdProvider);
  return ref.watch(localDatabaseProvider).vendorPayments.watchForShop(shopId);
});

final vendorPurchasesForVendorProvider = Provider.family<List<VendorPurchase>, String>((ref, vendorId) {
  final all = ref.watch(vendorPurchasesProvider).value ?? const <VendorPurchase>[];
  return all.where((p) => p.vendorId == vendorId).toList();
});

final vendorPaymentsForVendorProvider = Provider.family<List<VendorPayment>, String>((ref, vendorId) {
  final all = ref.watch(vendorPaymentsProvider).value ?? const <VendorPayment>[];
  return all.where((p) => p.vendorId == vendorId).toList();
});

final vendorOutstandingProvider = Provider.family<double, String>((ref, vendorId) {
  final purchases = ref.watch(vendorPurchasesForVendorProvider(vendorId));
  final payments = ref.watch(vendorPaymentsForVendorProvider(vendorId));
  final totalPurchase = purchases.fold<double>(0, (s, p) => s + p.amount);
  final totalPaid = payments.fold<double>(0, (s, p) => s + p.amount);
  return (totalPurchase - totalPaid).clamp(0.0, double.infinity).toDouble();
});

class VendorLedgerEntry {
  final String id;
  final String type; // 'purchase' or 'payment'
  final double amount;
  final DateTime date;
  final String description;
  final String? reference;
  final String? itemsSupplied;

  const VendorLedgerEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.description,
    this.reference,
    this.itemsSupplied,
  });
}

final vendorLedgerProvider = Provider.family<List<VendorLedgerEntry>, String>((ref, vendorId) {
  final purchases = ref.watch(vendorPurchasesForVendorProvider(vendorId));
  final payments = ref.watch(vendorPaymentsForVendorProvider(vendorId));

  final entries = <VendorLedgerEntry>[
    for (final p in purchases)
      VendorLedgerEntry(
        id: p.purchaseId,
        type: 'purchase',
        amount: p.amount,
        date: p.date,
        description: p.status.toUpperCase(),
        reference: p.notes.isNotEmpty ? p.notes : null,
        itemsSupplied: p.itemsSupplied.isNotEmpty ? p.itemsSupplied : null,
      ),
    for (final p in payments)
      VendorLedgerEntry(
        id: p.paymentId,
        type: 'payment',
        amount: p.amount,
        date: p.date,
        description: p.method.toUpperCase(),
        reference: p.reference.isNotEmpty ? p.reference : null,
        itemsSupplied: null,
      ),
  ];

  entries.sort((a, b) => a.date.compareTo(b.date));
  return entries;
});

final vendorServiceProvider = Provider<VendorService>((ref) {
  return VendorService(ref, const Uuid());
});

class VendorService {
  VendorService(this._ref, this._uuid);

  final Ref _ref;
  final Uuid _uuid;

  Future<Vendor> save({
    String? vendorId,
    required String companyName,
    required String contactPerson,
    required String phone,
    String email = '',
    String category = '',
    String address = '',
    String products = '',
    double rating = 0,
    String status = 'active',
  }) async {
    final now = DateTime.now();
    final db = _ref.read(localDatabaseProvider);
    final existing = vendorId == null
        ? null
        : db.vendors.getForShop(_ref.read(shopIdProvider), vendorId);
    final vendor = existing == null
        ? Vendor(
            vendorId: vendorId ?? _uuid.v4(),
            companyName: companyName,
            contactPerson: contactPerson,
            phone: phone,
            email: email,
            category: category,
            address: address,
            products: products,
            rating: rating,
            status: status,
            shopId: _ref.read(shopIdProvider),
            updatedAt: now,
            createdAt: now,
            syncStatus: SyncStatus.pending,
          )
        : existing.copyWith(
            companyName: companyName,
            contactPerson: contactPerson,
            phone: phone,
            email: email,
            category: category,
            address: address,
            products: products,
            rating: rating,
            status: status,
            updatedAt: now,
            syncStatus: SyncStatus.pending,
          );
    await db.vendors.put(vendor);
    await _ref.read(syncStateProvider.notifier).syncIfOnline();
    return vendor;
  }

  Future<void> delete(String vendorId) async {
    final db = _ref.read(localDatabaseProvider);
    final existing = db.vendors.getForShop(_ref.read(shopIdProvider), vendorId);
    if (existing == null) return;
    final deleted = existing.copyWith(
      isDeleted: true,
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );
    await db.vendors.put(deleted);
    await _ref.read(syncStateProvider.notifier).syncIfOnline();
  }

  Future<VendorPurchase> recordPurchase({
    required String vendorId,
    required double amount,
    DateTime? date,
    String status = 'pending',
    String notes = '',
    String itemsSupplied = '',
  }) async {
    final now = DateTime.now();
    final purchase = VendorPurchase(
      purchaseId: _uuid.v4(),
      vendorId: vendorId,
      amount: amount,
      date: date ?? now,
      status: status,
      notes: notes,
      itemsSupplied: itemsSupplied,
      shopId: _ref.read(shopIdProvider),
      updatedAt: now,
      syncStatus: SyncStatus.pending,
    );
    final db = _ref.read(localDatabaseProvider);
    await db.vendorPurchases.put(purchase);
    _ref.read(notificationServiceProvider).add(
          type: NotificationType.stock,
          title: 'Vendor stock received',
          message: '৳${amount.toStringAsFixed(2)} purchase recorded from vendor.',
          sourceKey: 'vendor-purchase:${purchase.purchaseId}',
        );

    final vendor = db.vendors.getForShop(_ref.read(shopIdProvider), vendorId);
    if (vendor != null) {
      final updatedProducts = itemsSupplied.isNotEmpty && !vendor.products.contains(itemsSupplied)
          ? (vendor.products.isEmpty ? itemsSupplied : '${vendor.products}, $itemsSupplied')
          : vendor.products;
      await db.vendors.put(vendor.copyWith(
        totalOrders: vendor.totalOrders + 1,
        totalSpent: vendor.totalSpent + amount,
        pendingAmount: vendor.pendingAmount + amount,
        lastPurchaseDate: date ?? now,
        products: updatedProducts,
        updatedAt: now,
        syncStatus: SyncStatus.pending,
      ));
    }

    await _ref.read(syncStateProvider.notifier).syncIfOnline();
    return purchase;
  }

  Future<VendorPayment> recordPayment({
    required String vendorId,
    required double amount,
    DateTime? date,
    String method = 'cash',
    String reference = '',
    String notes = '',
  }) async {
    final now = DateTime.now();
    final outstanding = _ref.read(vendorOutstandingProvider(vendorId));
    if (amount <= 0 || amount > outstanding) {
      throw StateError('Vendor payment must be positive and cannot exceed the outstanding balance.');
    }
    final payment = VendorPayment(
      paymentId: _uuid.v4(),
      vendorId: vendorId,
      amount: amount,
      date: date ?? now,
      method: method,
      reference: reference,
      notes: notes,
      shopId: _ref.read(shopIdProvider),
      updatedAt: now,
      syncStatus: SyncStatus.pending,
    );
    final db = _ref.read(localDatabaseProvider);
    await db.vendorPayments.put(payment);
    _ref.read(notificationServiceProvider).add(
          type: NotificationType.payment,
          title: 'Vendor payment recorded',
          message: '৳${amount.toStringAsFixed(2)} vendor payment recorded.',
          sourceKey: 'vendor-payment:${payment.paymentId}',
        );

    final vendor = db.vendors.getForShop(_ref.read(shopIdProvider), vendorId);
    if (vendor != null) {
      final newPending = (vendor.pendingAmount - amount).clamp(0.0, double.infinity);
      await db.vendors.put(vendor.copyWith(
        pendingAmount: newPending,
        updatedAt: now,
        syncStatus: SyncStatus.pending,
      ));
    }

    await _ref.read(syncStateProvider.notifier).syncIfOnline();
    return payment;
  }
}

const vendorCategories = [
  'Food & Beverage',
  'Dairy',
  'Personal Care',
  'Grains',
  'Beverages',
  'Meat & Poultry',
  'Health & Hygiene',
  'Vegetables',
  'Fruits',
  'Snacks',
  'Spices',
  'Frozen Foods',
  'Cleaning Supplies',
  'Packaging',
  'Other',
];
