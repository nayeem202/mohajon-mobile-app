import 'dart:convert';
import 'dart:typed_data';

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
    return _parse(response);
  }

  Future<VoiceBill> matchAudio(Uint8List wavBytes, {String mimeType = 'audio/wav'}) async {
    final response = await ApiClient(_db).post('/api/v1/assistant/bill-audio', {
      'audio': base64Encode(wavBytes),
      'mimeType': mimeType,
    });
    return _parse(response).copyWithTranscript(
      (response['transcript'] ?? '') as String,
    );
  }

  VoiceBill _parse(Map<String, dynamic> response) {
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
      transcript: (response['transcript'] ?? '') as String,
    );
  }
}