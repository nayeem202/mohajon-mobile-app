import 'package:flutter_test/flutter_test.dart';

import 'package:inventory_1/features/customers/services/due_recovery_service.dart';

void main() {
  test('follow-up status changes preserve delivery history identity', () {
    final createdAt = DateTime(2026, 10, 2, 10, 30);
    final original = DueFollowUp(
      id: 'follow-up-1',
      channel: DueFollowUpChannel.whatsapp,
      createdAt: createdAt,
      note: 'Reminder sent from customer profile',
      status: 'opened',
    );

    final delivered = original.copyWith(
      status: 'delivered',
      statusChangedAt: createdAt.add(const Duration(minutes: 2)),
      providerMessageId: 'provider-42',
    );

    expect(delivered.id, original.id);
    expect(delivered.channel, DueFollowUpChannel.whatsapp);
    expect(delivered.createdAt, createdAt);
    expect(delivered.note, original.note);
    expect(delivered.status, 'delivered');
    expect(delivered.providerMessageId, 'provider-42');
    expect(DueFollowUp.fromJson(delivered.toJson()).status, 'delivered');
  });
}
