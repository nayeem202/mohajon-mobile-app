import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/network_guard.dart';
import '../services/gemini_ask_client.dart';
import '../services/hambot_stats.dart';
import '../services/voice_assistant_service.dart';

/// "HamBot" — ask your shop questions by voice or text and get a friendly
/// answer from the AI assistant based on the shop's real data.
class HambotSheet extends ConsumerStatefulWidget {
  const HambotSheet({super.key});

  @override
  ConsumerState<HambotSheet> createState() => _HambotSheetState();
}

class _HambotSheetState extends ConsumerState<HambotSheet> {
  final VoiceAssistantService _service = VoiceAssistantService();
  final TextEditingController _textController = TextEditingController();
  final List<_ChatTurn> _turns = [];
  bool _busy = false;
  bool _matching = false;
  String? _error;

  @override
  void dispose() {
    _service.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _listen() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    final available = await _service.start();
    if (!mounted) return;
    if (!available) {
      setState(() {
        _busy = false;
        _error = AppLocalizations.of(context).t('voiceBillingUnavailable');
      });
    }
  }

  Future<void> _submitText() async {
    final text =
        _textController.text.trim().isEmpty
        ? null
        : _textController.text.trim();
    _textController.clear();
    await _ask(text: text);
  }

  /// Called on stop OR when the typed text is sent.
  Future<void> _stop() async {
    if (!_busy) return;
    setState(() {
      _busy = false;
      _matching = true;
    });
    final wav = await _service.stopAndGetWav();
    if (!mounted) return;
    if (wav == null || wav.isEmpty || _service.recordingPeak < 0.025) {
      setState(() {
        _matching = false;
        _error = AppLocalizations.of(context).t('voiceBillingNoSpeech');
      });
      return;
    }
    setState(() => _matching = false);
    await _ask(audio: wav);
  }

  Future<void> _ask({String? text, Uint8List? audio}) async {
    if ((text == null || text.isEmpty) && audio == null) return;
    final l10n = AppLocalizations.of(context);
    await requireInternetFor(context, () async {
      setState(() {
        _matching = true;
        _error = null;
      });
      if (text != null && text.isNotEmpty) {
        _turns.add(_ChatTurn(question: text, answer: null));
      } else if (audio != null) {
        _turns.add(_ChatTurn(question: l10n.t('hambotSpeaking'), answer: null));
      }
      try {
        final db = ref.read(localDatabaseProvider);
        final shopId = ref.read(shopIdProvider);
        final stats = HamBotStats.build(db, shopId: shopId);
        final HamBotAnswer result = audio != null
            ? await GeminiAskClient(db).askAudio(audio, statsJson: stats)
            : await GeminiAskClient(db).ask(text!, stats);
        if (!mounted) return;
        setState(() {
          _matching = false;
          _turns[_turns.length - 1] = _ChatTurn(
            question: _turns.last.question,
            answer: result.answer.isEmpty
                ? l10n.t('hambotNoAnswer')
                : result.answer,
          );
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _matching = false;
          final last = _turns.removeLast();
          if (_turns.isNotEmpty && _turns.last.answer == null) _turns.removeLast();
          _turns.add(_ChatTurn(question: last.question, answer: l10n.t('hambotAiError')));
        });
      }
    });
  }

  bool get _hasTurns => _turns.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.92,
      decoration: const BoxDecoration(
        color: MohajonWarm.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _header(l10n),
            const SizedBox(height: 8),
            Expanded(
              child: _hasTurns
                  ? ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      itemCount: _turns.length + (_matching ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _turns.length) {
                          return const _TypingIndicator();
                        }
                        final turn = _turns[index];
                        return _TurnBubble(turn: turn);
                      },
                    )
                  : _IdleHint(l10n: l10n),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _ErrorBanner(message: _error!),
              ),
            _inputBar(l10n),
          ],
        ),
      ),
    );
  }

  Widget _header(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: MohajonWarm.orange,
            ),
            child: const Icon(Icons.support_agent_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HamBot',
                style: const TextStyle(
                  color: MohajonWarm.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                l10n.t('hambotSubtitle'),
                style: const TextStyle(
                  color: MohajonWarm.muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (_busy)
            _buildMultiStatePulse()
          else
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded, color: MohajonWarm.muted),
            ),
        ],
      ),
    );
  }

  Widget _buildMultiStatePulse() {
    return ValueListenableBuilder<double>(
      valueListenable: _service.level,
      builder: (context, level, _) {
        return Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _levelBar(level, 0),
              _levelBar(level, 1),
              _levelBar(level, 2),
            ],
          ),
        );
      },
    );
  }

  Widget _levelBar(double level, int index) {
    final on = level >= (index + 1) * 0.22;
    return Container(
      width: 5,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: on ? MohajonWarm.orange : MohajonWarm.goldBorder,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _inputBar(AppLocalizations l10n) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        4,
        12,
        10 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Row(
        children: [
          if (!_busy) ...[
            Expanded(
              child: TextField(
                controller: _textController,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submitText(),
                decoration: InputDecoration(
                  hintText: l10n.t('hambotHint'),
                  filled: true,
                  fillColor: MohajonWarm.card,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              heroTag: 'hambot-ask',
              onPressed: _busy ? null : _submitText,
              backgroundColor: MohajonWarm.green,
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          GestureDetector(
            onTap: _busy ? _stop : _listen,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _busy
                    ? MohajonWarm.red
                    : MohajonWarm.orange,
              ),
              child: Icon(
                _busy ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatTurn {
  const _ChatTurn({required this.question, this.answer});

  final String question;
  final String? answer;
}

class _TurnBubble extends StatelessWidget {
  const _TurnBubble({required this.turn});

  final _ChatTurn turn;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            constraints: const BoxConstraints(maxWidth: 300),
            decoration: BoxDecoration(
              color: MohajonWarm.orange,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(6),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Text(
              turn.question,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ),
        if (turn.answer != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: const BoxConstraints(maxWidth: 320),
              decoration: BoxDecoration(
                color: MohajonWarm.card,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border.all(color: MohajonWarm.goldBorder),
              ),
              child: Text(
                turn.answer!,
                style: const TextStyle(
                  color: MohajonWarm.ink,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text('HamBot…', style: TextStyle(color: MohajonWarm.goldText)),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: MohajonWarm.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MohajonWarm.red.withValues(alpha: 0.4)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: MohajonWarm.red, fontSize: 13),
      ),
    );
  }
}

class _IdleHint extends StatelessWidget {
  const _IdleHint({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MohajonWarm.tintYellow,
                border: Border.all(color: MohajonWarm.goldBorder),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: MohajonWarm.orange, size: 26),
            ),
            const SizedBox(height: 14),
            const Text(
              'HamBot',
              style: TextStyle(
                color: MohajonWarm.ink,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.t('hambotSubtitle'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: MohajonWarm.muted, fontSize: 13),
            ),
            const SizedBox(height: 18),
            _ExampleChip(text: 'আজ কত বিক্রি হয়েছে?'),
            const SizedBox(height: 8),
            _ExampleChip(text: 'কে আমার বেশি বাকি?'),
            const SizedBox(height: 8),
            _ExampleChip(text: 'কোন পণ্য স্টকে কম আছে?'),
          ],
        ),
      ),
    );
  }
}

class _ExampleChip extends StatelessWidget {
  const _ExampleChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: MohajonWarm.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MohajonWarm.goldBorder),
      ),
      child: Text(
        text,
        style: const TextStyle(color: MohajonWarm.goldText, fontSize: 13),
      ),
    );
  }
}