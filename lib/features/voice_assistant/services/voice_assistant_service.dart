import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceAssistantService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final ValueNotifier<bool> listening = ValueNotifier<bool>(false);
  final ValueNotifier<String> transcript = ValueNotifier<String>('');
  bool _available = false;

  Future<bool> initialize() async {
    _available = await _speech.initialize(
      onStatus: (status) => listening.value = status == 'listening',
      onError: (error) {
        listening.value = false;
        debugPrint('Voice recognition error: ${error.errorMsg}');
      },
    );
    return _available;
  }

  Future<bool> start() async {
    if (!_available && !await initialize()) return false;
    transcript.value = '';
    await _speech.listen(
      onResult: (result) => transcript.value = result.recognizedWords,
      listenOptions: stt.SpeechListenOptions(
        listenFor: const Duration(seconds: 12),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
      ),
    );
    listening.value = true;
    return true;
  }

  Future<void> stop() async {
    await _speech.stop();
    listening.value = false;
  }

  Future<void> cancel() async {
    await _speech.cancel();
    listening.value = false;
  }

  void dispose() {
    listening.dispose();
    transcript.dispose();
  }
}
