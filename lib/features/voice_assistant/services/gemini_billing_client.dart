import '../../../core/offline/local_database.dart';
import '../../../core/services/api_client.dart';
import '../models/voice_bill.dart';

class GeminiBillingClient {
  GeminiBillingClient(this._db);

  final LocalDatabase _db;

  Future<VoiceBill> match(String transcript) async {
    final response = await ApiClient(_db).post('/api/v1/assistant/bill', {
      'text': transcript,
    });
    final items = <VoiceBillItem>[];
    final rawItems = response['items'];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is! Map) continue;
        items.add(
          VoiceBillItem(
            productId: (raw['productId'] ?? '') as String,
            nameEn: (raw['nameEn'] ?? '') as String,
            nameBn: (raw['nameBn'] ?? '') as String,
            quantity: (raw['quantity'] as num? ?? 1).toDouble(),
            sellingPrice: (raw['sellingPrice'] as num? ?? 0).toDouble(),
            stockQty: (raw['stockQty'] as num? ?? 0).toInt(),
            unit: (raw['unit'] ?? 'pcs') as String,
          ),
        );
      }
    }
    return VoiceBill(
      items: items,
      reply: (response['reply'] ?? '') as String,
    );
  }
}