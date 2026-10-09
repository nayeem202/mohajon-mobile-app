import 'dart:convert';
import 'dart:typed_data';

import '../../../core/offline/local_database.dart';
import '../../../core/services/api_client.dart';

class GeminiAskClient {
  GeminiAskClient(this._db);

  final LocalDatabase _db;

  Future<HamBotAnswer> ask(
    String question,
    String statsJson, {
    required String languageCode,
  }) async {
    final response = await ApiClient(_db).post('/api/v1/assistant/ask', {
      'text': question,
      'stats': statsJson,
      'language': languageCode,
    }, timeout: const Duration(seconds: 60));
    return HamBotAnswer(
      answer: (response['answer'] ?? '') as String,
      transcript: (response['transcript'] ?? question) as String,
    );
  }

  Future<HamBotAnswer> askAudio(
    Uint8List wavBytes, {
    required String statsJson,
    required String languageCode,
    String mimeType = 'audio/wav',
  }) async {
    final response = await ApiClient(_db).post('/api/v1/assistant/ask-audio', {
      'audio': base64Encode(wavBytes),
      'mimeType': mimeType,
      'stats': statsJson,
      'language': languageCode,
    }, timeout: const Duration(seconds: 60));
    return HamBotAnswer(
      answer: (response['answer'] ?? '') as String,
      transcript: (response['transcript'] ?? '') as String,
    );
  }
}

class HamBotAnswer {
  const HamBotAnswer({required this.answer, required this.transcript});

  final String answer;
  final String transcript;
}
