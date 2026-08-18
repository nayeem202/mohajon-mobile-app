import 'package:flutter/material.dart';

import '../../../core/offline/local_database.dart';
import '../models/voice_command.dart';
import '../services/gemini_command_client.dart';
import '../services/voice_assistant_service.dart';

class VoiceAssistantButton extends StatelessWidget {
  const VoiceAssistantButton({super.key, required this.onCommand, required this.database});

  final ValueChanged<VoiceCommand> onCommand;
  final LocalDatabase database;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'voice-assistant',
      tooltip: 'Voice assistant',
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => VoiceAssistantSheet(onCommand: onCommand, database: database),
      ),
      child: const Icon(Icons.mic_rounded),
    );
  }
}

class VoiceAssistantSheet extends StatefulWidget {
  const VoiceAssistantSheet({super.key, required this.onCommand, required this.database});

  final ValueChanged<VoiceCommand> onCommand;
  final LocalDatabase database;

  @override
  State<VoiceAssistantSheet> createState() => _VoiceAssistantSheetState();
}

class _VoiceAssistantSheetState extends State<VoiceAssistantSheet> {
  final VoiceAssistantService _service = VoiceAssistantService();
  String? _error;
  bool _busy = false;
  bool _usingAi = false;

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _listen() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    final available = await _service.start();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!available) {
        _error = 'Voice recognition is unavailable. Please check microphone permission.';
      }
    });
  }

  Future<void> _stop() async {
    await _service.stop();
    if (mounted) setState(() {});
  }

  Future<void> _runCommand() async {
    final transcript = _service.transcript.value.trim();
    if (transcript.isEmpty) {
      setState(() => _error = 'কিছু শোনা যায়নি। আবার পরিষ্কার করে বলুন।');
      return;
    }
    final command = VoiceCommandParser.parse(transcript);
    var resolved = command;
    if (!command.isKnown) {
      setState(() {
        _busy = true;
        _usingAi = true;
        _error = null;
      });
      try {
        resolved = await GeminiCommandClient(widget.database).interpret(transcript);
      } catch (_) {
        if (mounted) {
          setState(() {
            _busy = false;
            _usingAi = false;
            _error = 'এই command বুঝতে পারিনি। আরও পরিষ্কার করে বলুন।';
          });
        }
        return;
      }
      if (!resolved.isKnown) {
        setState(() {
          _busy = false;
          _usingAi = false;
          _error = 'এই command এখনো supported নয়। Products, Sales বা Customers বলুন।';
        });
        return;
      }
    }
    if (!mounted) return;
    widget.onCommand(resolved);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + MediaQuery.viewInsetsOf(context).bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ValueListenableBuilder<bool>(
        valueListenable: _service.listening,
        builder: (context, listening, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Voice Assistant', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                ),
                IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
              ],
            ),
            Text(_usingAi
                ? 'AI command বুঝছে...'
                : 'বলুন: “Products খুলুন” বা “আজকের sales দেখাও”'),
            const SizedBox(height: 18),
            ValueListenableBuilder<String>(
              valueListenable: _service.transcript,
              builder: (context, transcript, _) => Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 72),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(14)),
                child: Text(
                  transcript.isEmpty ? 'আপনার command এখানে দেখা যাবে' : transcript,
                  style: TextStyle(color: transcript.isEmpty ? Colors.black45 : Colors.black87, fontSize: 16),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: Colors.red.shade700)),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : (listening ? _stop : _listen),
                    icon: Icon(listening ? Icons.stop_rounded : Icons.mic_rounded),
                    label: Text(listening ? 'Stop' : 'Speak'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: listening ? null : _runCommand,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(_usingAi ? 'Processing...' : 'Run command'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
