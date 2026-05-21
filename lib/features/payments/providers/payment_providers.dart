import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/syncable.dart';

final paymentsProvider = StreamProvider<List<Payment>>((ref) {
  final shopId = ref.watch(shopIdProvider);
  return ref.watch(localDatabaseProvider).payments.watchForShop(shopId);
});

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService(ref, const Uuid());
});

class PaymentService {
  PaymentService(this._ref, this._uuid);

  final Ref _ref;
  final Uuid _uuid;

  Future<void> addPayment({
    required String customerId,
    String? saleId,
    required double amount,
    required PaymentMethod method,
  }) async {
    final now = DateTime.now();
    await _ref.read(localDatabaseProvider).payments.put(
          Payment(
            paymentId: _uuid.v4(),
            customerId: customerId,
            saleId: saleId,
            amount: amount,
            paymentMethod: method,
            shopId: _ref.read(shopIdProvider),
            createdAt: now,
            updatedAt: now,
            syncStatus: SyncStatus.pending,
          ),
        );
    await _ref.read(syncStateProvider.notifier).syncIfOnline();
  }
}
