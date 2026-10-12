import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/api_client.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/network_guard.dart';
import '../../subscription/providers/subscription_providers.dart';
import '../services/gemini_ask_client.dart';
import '../services/hambot_stats.dart';
import '../services/mohajon_tts.dart';
import '../services/verified_business_answer_service.dart';
import '../services/voice_assistant_service.dart';

/// "Mohajon AI" — ask your shop questions by voice or text and get a friendly
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
  String _replyLanguageOverride = 'auto';
  MohajonTts? _tts;

  @override
  void initState() {
    super.initState();
    _tts = MohajonTts(ref.read(localDatabaseProvider));
    _tts!.init();
  }

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    final tts = _tts;
    if (tts == null) return;
    await tts.speak(text);
  }

  Future<void> _stopSpeaking() async {
    await _tts?.stop();
  }

  @override
  void dispose() {
    _tts?.dispose();
    _service.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _listen() async {
    await _stopSpeaking();
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
    final text = _textController.text.trim().isEmpty
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
    final responseLanguageCode = _responseLanguageCode(text);
    final db = ref.read(localDatabaseProvider);
    final shopId = ref.read(shopIdProvider);

    // Common questions are answered from the shop's own records first. This
    // works without internet and avoids asking an AI provider to calculate a
    // sales, stock, expense or due number.
    if (text != null && text.isNotEmpty) {
      final verified = VerifiedBusinessAnswerService.answer(
        db,
        shopId: shopId,
        question: text,
        languageCode: responseLanguageCode,
      );
      if (verified != null) {
        setState(() {
          _error = null;
          _turns.add(
            _ChatTurn(
              question: text,
              answer: verified.answer,
              source: verified.source,
              isVerified: true,
            ),
          );
        });
        await _speak(verified.answer);
        return;
      }
    }

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
        final stats = HamBotStats.build(db, shopId: shopId);
        final HamBotAnswer result = audio != null
            ? await GeminiAskClient(db).askAudio(
                audio,
                statsJson: stats,
                languageCode: responseLanguageCode,
              )
            : await GeminiAskClient(
                db,
              ).ask(text!, stats, languageCode: responseLanguageCode);
        if (!mounted) return;
        // The subscription screen caches this FutureProvider. Invalidate it
        // after a billable server answer so returning to that screen fetches
        // the current server-side balance instead of showing stale credits.
        ref.invalidate(aiCreditStatusProvider);
        setState(() {
          _matching = false;
          _turns[_turns.length - 1] = _ChatTurn(
            question: _turns.last.question,
            answer: result.answer.isEmpty
                ? l10n.tForLanguage('hambotNoAnswer', responseLanguageCode)
                : result.answer,
            source: l10n.tForLanguage('hambotSource', responseLanguageCode),
          );
        });
        final answer = result.answer.isEmpty
            ? l10n.tForLanguage('hambotNoAnswer', responseLanguageCode)
            : result.answer;
        await _speak(answer);
      } catch (err) {
        if (!mounted) return;
        final isQuota =
            err is ApiException &&
            (err.code == 'AI_UNAVAILABLE' || err.statusCode == 429);
        setState(() {
          _matching = false;
          final last = _turns.removeLast();
          if (_turns.isNotEmpty && _turns.last.answer == null) {
            _turns.removeLast();
          }
          _turns.add(
            _ChatTurn(
              question: last.question,
              answer: l10n.tForLanguage(
                isQuota ? 'hambotQuotaExhausted' : 'hambotAiError',
                responseLanguageCode,
              ),
              isError: true,
            ),
          );
        });
      }
    });
  }

  String _responseLanguageCode(String? question) {
    if (_replyLanguageOverride == 'bn' || _replyLanguageOverride == 'en') {
      return _replyLanguageOverride;
    }
    // Keep replies aligned with the app preference, but honor a Bengali-script
    // question even when the surrounding UI is set to English.
    if (question != null && RegExp(r'[\u0980-\u09FF]').hasMatch(question)) {
      return 'bn';
    }
    return Localizations.localeOf(context).languageCode;
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
                        return _TurnBubble(
                          turn: turn,
                          onSpeak: (turn.answer != null && !turn.isError)
                              ? () => _speak(turn.answer!)
                              : null,
                        );
                      },
                    )
                  : _IdleHint(
                      l10n: l10n,
                      onPromptTap: (text) => _ask(text: text),
                    ),
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
            child: const Icon(
              Icons.support_agent_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Mohajon AI',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MohajonWarm.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  l10n.t('hambotSubtitle'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MohajonWarm.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: l10n.t('hambotReplyLanguage'),
            initialValue: _replyLanguageOverride,
            onSelected: (value) =>
                setState(() => _replyLanguageOverride = value),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'auto',
                child: Text(l10n.t('hambotReplyAuto')),
              ),
              PopupMenuItem(
                value: 'bn',
                child: Text(l10n.t('hambotReplyBangla')),
              ),
              PopupMenuItem(
                value: 'en',
                child: Text(l10n.t('hambotReplyEnglish')),
              ),
            ],
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(
                Icons.translate_rounded,
                color: MohajonWarm.muted,
                size: 20,
              ),
            ),
          ),
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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
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
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 18,
              ),
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
                color: _busy ? MohajonWarm.red : MohajonWarm.orange,
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
  const _ChatTurn({
    required this.question,
    this.answer,
    this.source,
    this.isVerified = false,
    this.isError = false,
  });

  final String question;
  final String? answer;
  final String? source;
  final bool isVerified;
  final bool isError;
}

class _TurnBubble extends StatelessWidget {
  const _TurnBubble({required this.turn, this.onSpeak});

  final _ChatTurn turn;
  final VoidCallback? onSpeak;

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
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width < 400
                  ? MediaQuery.sizeOf(context).width * 0.78
                  : 320,
            ),
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
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width < 400
                    ? MediaQuery.sizeOf(context).width * 0.78
                    : 320,
              ),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Text(
                          turn.answer!,
                          style: const TextStyle(
                            color: MohajonWarm.ink,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                      if (onSpeak != null) ...[
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: onSpeak,
                          borderRadius: BorderRadius.circular(20),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.volume_up_rounded,
                              size: 17,
                              color: MohajonWarm.orange,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (turn.source != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: turn.isVerified
                            ? MohajonWarm.tintGreen
                            : MohajonWarm.tintYellow,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${turn.isVerified ? '✓ ' : ''}${turn.source}',
                        style: TextStyle(
                          color: turn.isVerified
                              ? MohajonWarm.green
                              : MohajonWarm.goldText,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
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
        child: Text(
          'Mohajon AI…',
          style: TextStyle(color: MohajonWarm.goldText),
        ),
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
  const _IdleHint({required this.l10n, required this.onPromptTap});

  final AppLocalizations l10n;
  final ValueChanged<String> onPromptTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
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
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: MohajonWarm.orange,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Mohajon AI',
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
                    style: const TextStyle(
                      color: MohajonWarm.muted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.t('hambotLanguageHint'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: MohajonWarm.goldText,
                      fontSize: 11.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final key in const [
                    'hambotSuggestionSales',
                    'hambotSuggestionDue',
                    'hambotSuggestionStock',
                    'hambotSuggestionCash',
                  ]) ...[
                    _ExampleChip(
                      text: l10n.t(key),
                      onTap: () => onPromptTap(l10n.t(key)),
                    ),
                    if (key != 'hambotSuggestionCash')
                      const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExampleChip extends StatelessWidget {
  const _ExampleChip({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MohajonWarm.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: MohajonWarm.goldBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: MohajonWarm.goldText, fontSize: 13),
          ),
        ),
      ),
    );
  }
}
