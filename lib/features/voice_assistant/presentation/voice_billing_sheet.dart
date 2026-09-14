import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/product.dart';
import '../../../core/utils/money.dart';
import '../../pos/providers/cart_provider.dart';
import '../models/voice_bill.dart';
import '../services/gemini_billing_client.dart';
import '../services/voice_assistant_service.dart';

class VoiceBillingSheet extends ConsumerStatefulWidget {
  const VoiceBillingSheet({super.key});

  @override
  ConsumerState<VoiceBillingSheet> createState() => _VoiceBillingSheetState();
}

class _VoiceBillingSheetState extends ConsumerState<VoiceBillingSheet> {
  final VoiceAssistantService _service = VoiceAssistantService();
  String? _error;
  bool _busy = false;
  bool _matching = false;
  VoiceBill? _bill;

  List<VoiceBillItem> get _items =>
      _bill?.items.map((item) => item.copyWith()).toList() ?? const [];

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _listen() async {
    setState(() {
      _error = null;
      _bill = null;
      _busy = true;
    });
    final available = await _service.start();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!available) {
      setState(() => _error = AppLocalizations.of(context).t('voiceBillingUnavailable'));
    }
  }

  Future<void> _stop() async {
    await _service.stop();
    if (mounted) setState(() {});
  }

  Future<void> _match() async {
    final l10n = AppLocalizations.of(context);
    final transcript = _service.transcript.value.trim();
    if (transcript.isEmpty) {
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
          .match(transcript);
      if (!mounted) return;
      setState(() {
        _matching = false;
        _bill = bill;
      });
      if (!bill.hasMatches) {
        setState(() => _error = l10n.t('voiceBillingNoMatch'));
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
    final db = ref.read(localDatabaseProvider);
    final shopId = ref.read(shopIdProvider);
    final cart = ref.read(cartProvider.notifier);
    final items = _items;
    var added = 0;
    var unresolved = 0;
    for (final item in items) {
      final Product? product = db.products.getForShop(shopId, item.productId);
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
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.t('voiceBillingTitle'),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                const Icon(Icons.mic_rounded, color: Color(0xFFE98300)),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(l10n.t('voiceBillingHint'), style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 16),
            ValueListenableBuilder<String>(
              valueListenable: _service.transcript,
              builder: (context, transcript, _) => Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 72),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  transcript.isEmpty ? l10n.t('voiceBillingListening') : transcript,
                  style: TextStyle(
                    color: transcript.isEmpty ? Colors.black45 : Colors.black87,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: Colors.red.shade700)),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _matching ? null : (_busy ? _stop : _listen),
                    icon: Icon(_busy ? Icons.stop_rounded : Icons.mic_rounded),
                    label: Text(_busy ? l10n.t('voiceBillingStop') : l10n.t('voiceBillingSpeak')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (_busy || _matching) ? null : _match,
                    icon: Icon(_matching ? Icons.hourglass_top_rounded : Icons.search_rounded),
                    label: Text(_matching ? l10n.t('voiceBillingProcessing') : l10n.t('voiceBillingRun')),
                  ),
                ),
              ],
            ),
            if (_bill != null && items.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                l10n.tP('voiceBillingItemsFound', {'count': '${items.length}'}),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const SizedBox(height: 8),
              for (final item in items) ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.nameBn.isNotEmpty && _isBangla(l10n)
                                ? item.nameBn
                                : item.nameEn,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${money(item.sellingPrice)} / ${item.unit}',
                            style: const TextStyle(color: Colors.black54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _changeQty(item.productId, -0.5),
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                    ),
                    SizedBox(
                      width: 44,
                      child: Text(
                        item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 1),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _changeQty(item.productId, 0.5),
                      icon: const Icon(Icons.add_circle_outline_rounded),
                    ),
                    SizedBox(
                      width: 74,
                      child: Text(
                        money(item.sellingPrice * item.quantity),
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFE98300)),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _addToCart,
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  label: Text(l10n.t('voiceBillingAddToCart')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _isBangla(AppLocalizations l10n) => l10n.locale.languageCode == 'bn';
}