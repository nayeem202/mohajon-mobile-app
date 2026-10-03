import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/product.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/network_guard.dart';
import '../../pos/providers/cart_provider.dart';
import '../../products/providers/product_providers.dart';
import '../models/voice_bill.dart';
import '../services/gemini_billing_client.dart';
import '../services/voice_assistant_service.dart';

class VoiceBillingSheet extends ConsumerStatefulWidget {
  const VoiceBillingSheet({super.key});

  @override
  ConsumerState<VoiceBillingSheet> createState() => _VoiceBillingSheetState();
}

class _VoiceBillingSheetState extends ConsumerState<VoiceBillingSheet>
    with SingleTickerProviderStateMixin {
  final VoiceAssistantService _service = VoiceAssistantService();
  String? _error;
  bool _busy = false;
  bool _matching = false;
  VoiceBill? _bill;
  Uint8List? _pendingAudio;
  late AnimationController _pulseController;

  List<VoiceBillItem> get _items =>
      _bill?.items.map((item) => item.copyWith()).toList() ?? const [];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _service.dispose();
    super.dispose();
  }

  void _startPulse() {
    _pulseController.repeat(reverse: true);
  }

  void _stopPulse() {
    _pulseController.stop();
    _pulseController.reset();
  }

  Future<void> _listen() async {
    debugPrint('VOICE: _listen start');
    setState(() {
      _error = null;
      _bill = null;
      _pendingAudio = null;
      _busy = true;
    });
    _startPulse();
    bool available;
    try {
      available = await _service.start();
    } catch (e, st) {
      debugPrint('VOICE: start threw $e\n$st');
      available = false;
    }
    debugPrint('VOICE: _listen available=$available busy=$_busy');
    if (!mounted) return;
    if (!available) {
      _stopPulse();
      setState(() {
        _busy = false;
        _error = AppLocalizations.of(context).t('voiceBillingUnavailable');
      });
    }
  }

  Future<void> _stop() async {
    debugPrint('VOICE: _stop start');
    _stopPulse();
    setState(() {
      _busy = false;
      _matching = true;
    });
    final wav = await _service.stopAndGetWav();
    debugPrint('VOICE: stopAndGetWav done, wav=${wav?.length} peak=${_service.recordingPeak}');
    if (!mounted) return;
    final silent = wav == null ||
        wav.isEmpty ||
        _service.recordingPeak < 0.025;
    if (silent) {
      setState(() {
        _matching = false;
        _error = AppLocalizations.of(context).t('voiceBillingNoSpeech');
      });
      return;
    }
    setState(() {
      _pendingAudio = wav;
      _matching = false;
    });
    await _match();
  }

  Future<void> _match() async {
    debugPrint('VOICE: _match start audio=${_pendingAudio?.length}');
    final l10n = AppLocalizations.of(context);
    final audio = _pendingAudio;
    if (audio == null || audio.isEmpty) {
      setState(() => _error = l10n.t('voiceBillingNoSpeech'));
      return;
    }
    await requireInternetFor(context, _doMatch);
  }

  Future<void> _doMatch() async {
    final l10n = AppLocalizations.of(context);
    final audio = _pendingAudio;
    if (audio == null || audio.isEmpty) {
      setState(() => _error = l10n.t('voiceBillingNoSpeech'));
      return;
    }
    setState(() {
      _matching = true;
      _error = null;
      _bill = null;
    });
    try {
      final bill = await GeminiBillingClient(ref.read(localDatabaseProvider))
          .matchAudio(audio);
      if (!mounted) return;
      setState(() {
        _matching = false;
        _bill = bill;
        _service.transcript.value = bill.transcript;
      });
      if (!bill.hasMatches) {
        setState(() {
          _error = bill.reply.isNotEmpty ? bill.reply : l10n.t('voiceBillingNoMatch');
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _matching = false;
        _error = l10n.t('voiceBillingAiError');
      });
    }
  }

  Future<void> _addToCart() async {
    final l10n = AppLocalizations.of(context);
    final cart = ref.read(cartProvider.notifier);
    final items = _items;
    var added = 0;
    var unresolved = 0;
    for (final item in items) {
      final Product? product = ref
          .read(productServiceProvider)
          .getActiveBranchProduct(item.productId);
      if (product == null) {
        unresolved++;
        continue;
      }
      cart.addProduct(product);
      cart.setQty(item.productId, item.quantity);
      added++;
    }
    final messenger = ScaffoldMessenger.of(context);
    if (mounted) Navigator.of(context).pop(added);
    if (added > 0) {
      final message = unresolved == 0
          ? l10n.tP('voiceBillingAdded', {'count': '$added'})
          : l10n.tP('voiceBillingAddedSome', {'count': '$added'});
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.t('voiceBillingAddFailed'))),
      );
    }
  }

  void _changeQty(String productId, double delta) {
    final bill = _bill;
    if (bill == null) return;
    setState(() {
      _bill = VoiceBill(
        items: [
          for (final item in bill.items)
            item.productId == productId
                ? item.copyWith(quantity: (item.quantity + delta).clamp(0.5, 999))
                : item,
        ],
        reply: bill.reply,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = _items;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: MohajonWarm.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(l10n),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTranscriptArea(l10n),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    _buildErrorBanner(l10n),
                  ],
                  const SizedBox(height: 16),
                  _buildActionButtons(l10n),
                  if (_bill != null && items.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildMatchedItems(items, l10n),
                    const SizedBox(height: 16),
                    _buildAddToCartButton(l10n),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: MohajonWarm.goldBorder,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.t('voiceBillingTitle'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: MohajonWarm.ink,
                  ),
                ),
              ),
              _buildMicIndicator(),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: MohajonWarm.muted),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            l10n.t('voiceBillingHint'),
            style: const TextStyle(color: MohajonWarm.muted, fontSize: 13),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildLevelBars(double level) {
    final bars = <Widget>[];
    const count = 5;
    for (var i = 0; i < count; i++) {
      final factor = (i + 1) / count;
      final on = level >= factor * 0.55;
      bars.add(Container(
        width: 4,
        height: 16,
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        decoration: BoxDecoration(
          color: on ? MohajonWarm.orange : MohajonWarm.goldBorder,
          borderRadius: BorderRadius.circular(3),
        ),
      ));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: bars);
  }

  Widget _buildMicIndicator() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final t = _pulseController.value;
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _busy
                ? MohajonWarm.orange.withValues(alpha: 0.12 + t * 0.18)
                : MohajonWarm.tintYellow,
            border: Border.all(
              color: _busy
                  ? MohajonWarm.orange.withValues(alpha: 0.3 + t * 0.4)
                  : MohajonWarm.goldBorder,
            ),
          ),
          child: Icon(
            _busy ? Icons.mic_rounded : Icons.mic_none_rounded,
            size: 18,
            color: _busy ? MohajonWarm.orange : MohajonWarm.goldText,
          ),
        );
      },
    );
  }

  Widget _buildTranscriptArea(AppLocalizations l10n) {
    return ValueListenableBuilder<String>(
      valueListenable: _service.transcript,
      builder: (context, transcript, _) {
        final hasText = transcript.isNotEmpty;
        return Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 80),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MohajonWarm.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _busy ? MohajonWarm.orange.withValues(alpha: 0.35) : MohajonWarm.goldBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_busy)
                ValueListenableBuilder<double>(
                  valueListenable: _service.level,
                  builder: (context, level, _) {
                    return Row(
                      children: [
                        _buildLevelBars(level),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.t('voiceBillingListening'),
                            style: const TextStyle(
                              color: MohajonWarm.orange,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                )
              else if (!hasText)
                Row(
                  children: [
                    Icon(
                      Icons.hearing_rounded,
                      size: 16,
                      color: MohajonWarm.muted.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.t('voiceBillingIdle'),
                        style: const TextStyle(
                          color: MohajonWarm.muted,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                )
              else
                Text(
                  transcript,
                  style: TextStyle(
                    color: MohajonWarm.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorBanner(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: MohajonWarm.tintRed,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MohajonWarm.red.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: MohajonWarm.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                color: MohajonWarm.red,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _matching ? null : (_busy ? _stop : _listen),
            style: OutlinedButton.styleFrom(
              foregroundColor: _busy ? MohajonWarm.red : MohajonWarm.ink,
              side: BorderSide(
                color: _busy ? MohajonWarm.red.withValues(alpha: 0.3) : MohajonWarm.goldBorder,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              minimumSize: const Size(0, 48),
            ),
            icon: Icon(_busy ? Icons.stop_rounded : Icons.mic_rounded, size: 20),
            label: Text(
              _busy ? l10n.t('voiceBillingStop') : l10n.t('voiceBillingSpeak'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: (_busy || _matching || (_pendingAudio == null))
                ? null
                : _match,
            style: FilledButton.styleFrom(
              backgroundColor: MohajonWarm.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              minimumSize: const Size(0, 48),
            ),
            icon: _matching
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.auto_awesome_rounded, size: 20),
            label: Text(
              _matching ? l10n.t('voiceBillingProcessing') : l10n.t('voiceBillingRun'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMatchedItems(List<VoiceBillItem> items, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: MohajonWarm.green,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              l10n.tP('voiceBillingItemsFound', {'count': '${items.length}'}),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: MohajonWarm.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final item in items) ...[
          _buildItemCard(item),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildItemCard(VoiceBillItem item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MohajonWarm.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MohajonWarm.goldBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nameBn.isNotEmpty && _isBangla(AppLocalizations.of(context))
                      ? item.nameBn
                      : item.nameEn,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: MohajonWarm.ink,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${money(item.sellingPrice)} / ${item.unit}',
                  style: const TextStyle(
                    color: MohajonWarm.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _buildQtyButton(
            icon: Icons.remove_rounded,
            onTap: () => _changeQty(item.productId, -0.5),
          ),
          SizedBox(
            width: 44,
            child: Text(
              item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 1),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: MohajonWarm.ink,
              ),
            ),
          ),
          _buildQtyButton(
            icon: Icons.add_rounded,
            onTap: () => _changeQty(item.productId, 0.5),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 74,
            child: Text(
              money(item.sellingPrice * item.quantity),
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: MohajonWarm.orange,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQtyButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: MohajonWarm.tintYellow,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: MohajonWarm.goldText),
      ),
    );
  }

  Widget _buildAddToCartButton(AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _addToCart,
        style: FilledButton.styleFrom(
          backgroundColor: MohajonWarm.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          minimumSize: const Size(0, 52),
        ),
        icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
        label: Text(
          l10n.t('voiceBillingAddToCart'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
    );
  }

  bool _isBangla(AppLocalizations l10n) => l10n.locale.languageCode == 'bn';
}
