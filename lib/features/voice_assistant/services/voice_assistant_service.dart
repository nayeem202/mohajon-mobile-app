import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

/// Records real audio from the microphone and exposes it as a WAV byte blob
/// ready to be uploaded to the backend AI assistant.
class VoiceAssistantService {
  final AudioRecorder _recorder = AudioRecorder();
  final ValueNotifier<bool> listening = ValueNotifier<bool>(false);
  final ValueNotifier<String> transcript = ValueNotifier<String>('');
  final ValueNotifier<double> level = ValueNotifier<double>(0);

  static const _sampleRate = 16000;

  /// Highest sample amplitude (0..1) captured during the current take.
  double _recordingPeak = 0;

  /// Peak amplitude of the most recent take (0..1). Used to detect silence.
  double get recordingPeak => _recordingPeak;

  final List<Uint8List> _pcmChunks = [];
  StreamSubscription<Uint8List>? _subscription;

  Future<bool> start() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return false;
    transcript.value = '';
    level.value = 0;
    _recordingPeak = 0;
    _pcmChunks.clear();
    final stream = await _recorder.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
        bitRate: 128000,
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
      ),
    );
    _subscription = stream.listen(
      (chunk) {
        _pcmChunks.add(chunk);
        _updateLevel(chunk);
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Record stream error: $error');
      },
    );
    listening.value = true;
    return true;
  }

  /// Peak-to-peak level (0..1) from a 16-bit PCM chunk, smoothed.
  void _updateLevel(Uint8List chunk) {
    var max = 0;
    for (var i = 0; i + 1 < chunk.length; i += 2) {
      final sample = ((chunk[i] & 0xFF) | (chunk[i + 1] << 8)).toSigned(16);
      final abs = sample.abs();
      if (abs > max) max = abs;
    }
    final target = (max / 32767.0).clamp(0.0, 1.0);
    if (target > _recordingPeak) _recordingPeak = target;
    level.value += (target - level.value) * 0.4;
  }

  /// Stops recording and returns a WAV container of the captured PCM.
  Future<Uint8List?> stopAndGetWav() async {
    await _subscription?.cancel();
    _subscription = null;
    listening.value = false;
    level.value = 0;
    await _recorder.stop();
    if (_pcmChunks.isEmpty) return null;
    final wav = _buildWav(_pcmChunks, _sampleRate);
    _pcmChunks.clear();
    return wav;
  }

  /// Compatibility helper: stops and discards the captured audio.
  Future<void> stop() async {
    await stopAndGetWav();
  }

  Future<void> cancel() async {
    await _subscription?.cancel();
    _subscription = null;
    listening.value = false;
    level.value = 0;
    await _recorder.cancel();
    _pcmChunks.clear();
  }

  void dispose() {
    listening.dispose();
    transcript.dispose();
    level.dispose();
  }
}

Uint8List _buildWav(List<Uint8List> chunks, int sampleRate) {
  final dataSize = chunks.fold<int>(0, (sum, c) => sum + c.length);
  const headerSize = 44;
  final pcm = ByteData(headerSize + dataSize);

  void writeString(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      pcm.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  writeString(0, 'RIFF');
  pcm.setUint32(4, 36 + dataSize, Endian.little);
  writeString(8, 'WAVE');
  writeString(12, 'fmt ');
  pcm.setUint32(16, 16, Endian.little);
  pcm.setUint16(20, 1, Endian.little);
  pcm.setUint16(22, 1, Endian.little);
  pcm.setUint32(24, sampleRate, Endian.little);
  pcm.setUint32(28, sampleRate * 2, Endian.little);
  pcm.setUint16(32, 2, Endian.little);
  pcm.setUint16(34, 16, Endian.little);
  writeString(36, 'data');
  pcm.setUint32(40, dataSize, Endian.little);

  var offset = headerSize;
  for (final chunk in chunks) {
    pcm.buffer.asUint8List().setRange(offset, offset + chunk.length, chunk);
    offset += chunk.length;
  }
  return pcm.buffer.asUint8List();
}