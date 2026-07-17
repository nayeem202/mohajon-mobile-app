import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app/app_providers.dart';
import 'firestore_paths.dart';

final adminServiceProvider = Provider<AdminService>((ref) {
  return AdminService(ref);
});

class AdminService {
  AdminService(this._ref);

  final Ref _ref;
  String get _shopId => _ref.read(shopIdProvider);

  static const _collections = [
    'products',
    'customers',
    'sales',
    'customerLedgerEntries',
    'payments',
    'purchases',
    'suppliers',
    'users',
    'vendors',
    'vendor_purchases',
    'vendor_payments',
    'investments',
    'investors',
    'investment_members',
    'investment_categories',
    'payouts',
  ];

  Future<Map<String, dynamic>> clearAllShopData() async {
    final firestore = FirebaseFirestore.instance;
    final paths = FirestorePaths(firestore, _shopId);
    int deleted = 0;
    int failed = 0;
    final errors = <String>[];

    for (final name in _collections) {
      try {
        final col = paths.collection(name);
        final snap = await col.get();
        if (snap.docs.isEmpty) continue;

        final batches = _batchify(snap.docs.map((d) => d.reference).toList());
        for (final batch in batches) {
          try {
            final writeBatch = firestore.batch();
            for (final ref in batch) {
              writeBatch.delete(ref);
            }
            await writeBatch.commit();
            deleted += batch.length;
          } catch (e) {
            failed += batch.length;
            errors.add('$name: $e');
          }
        }
      } catch (e) {
        errors.add('$name: $e');
      }
    }

    return {
      'deleted': deleted,
      'failed': failed,
      'errors': errors,
    };
  }

  List<List<T>> _batchify<T>(List<T> items, [int size = 500]) {
    final batches = <List<T>>[];
    for (var i = 0; i < items.length; i += size) {
      batches.add(items.sublist(i, i + size > items.length ? items.length : i + size));
    }
    return batches;
  }
}
