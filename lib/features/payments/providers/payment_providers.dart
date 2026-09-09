import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/sale.dart';
import '../../../core/models/syncable.dart';
import '../../../core/utils/money.dart';
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
    final shopId = _ref.read(shopIdProvider);
    final amountRounded = moneyRound2(amount);
    if (saleId != null) {
      final sale = db.sales.getForShop(shopId, saleId);
      if (sale == null || sale.customerId != customerId) {
        throw StateError('The selected sale could not be found.');
      }
      final paymentsSum = db.payments
          .valuesForShop(shopId)
          .where((p) => p.saleId == saleId && !p.isDeleted)
          .fold<double>(0, (sum, p) => sum + p.amount);
      if (amountRounded > moneyRound2(sale.totalAmount - paymentsSum)) {
        throw StateError('Payment cannot exceed the remaining due amount.');
      }
      final newPaid = moneyRound2(paymentsSum + amountRounded);
      final newDue = moneyRound2(
        (sale.totalAmount - newPaid).clamp(0.0, double.infinity),
      );
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
            amount: amountRounded,
            paymentMethod: method,
            shopId: shopId,
            createdAt: now,
            updatedAt: now,
            syncStatus: SyncStatus.pending,
          ),
        );
    _ref.read(notificationServiceProvider).add(
          type: NotificationType.payment,
          title: 'Payment received',
          message: '৳${amountRounded.toStringAsFixed(2)} payment recorded.',
          sourceKey: 'payment:${now.microsecondsSinceEpoch}',
        );
    await _ref.read(syncStateProvider.notifier).syncIfOnline();
  }
}
