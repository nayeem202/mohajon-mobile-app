import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/sale.dart';
import '../../../core/models/syncable.dart';
import '../../notifications/models/notification_model.dart';
import '../../notifications/providers/notification_providers.dart';

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
    final db = _ref.read(localDatabaseProvider);
    if (saleId != null) {
      final sale = db.sales.getForShop(_ref.read(shopIdProvider), saleId);
      if (sale == null || sale.customerId != customerId) {
        throw StateError('The selected sale could not be found.');
      }
      if (amount > sale.dueAmount) {
        throw StateError('Payment cannot exceed the sale due amount.');
      }
      final newPaid = sale.paidAmount + amount;
      final newDue = (sale.totalAmount - newPaid).clamp(0.0, double.infinity);
      await db.sales.put(sale.copyWith(
        paidAmount: newPaid,
        dueAmount: newDue,
        paymentStatus: newDue == 0
            ? PaymentStatus.paid
            : PaymentStatus.partial,
        updatedAt: now,
        syncStatus: SyncStatus.pending,
      ));
    }
    await db.payments.put(
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
    _ref.read(notificationServiceProvider).add(
          type: NotificationType.payment,
          title: 'Payment received',
          message: '৳${amount.toStringAsFixed(2)} payment recorded.',
          sourceKey: 'payment:${now.microsecondsSinceEpoch}',
        );
    await _ref.read(syncStateProvider.notifier).syncIfOnline();
  }
}
