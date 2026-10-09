import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../customers/providers/customer_providers.dart';
import '../providers/shop_profile_providers.dart';

class CustomerRulesSettingsScreen extends ConsumerStatefulWidget {
  const CustomerRulesSettingsScreen({super.key});

  @override
  ConsumerState<CustomerRulesSettingsScreen> createState() =>
      _CustomerRulesSettingsScreenState();
}

class _CustomerRulesSettingsScreenState
    extends ConsumerState<CustomerRulesSettingsScreen> {
  final _vipThresholdCtrl = TextEditingController();
  final _regularThresholdCtrl = TextEditingController();
  final _offerPointsCtrl = TextEditingController();
  final _offerPercentCtrl = TextEditingController();
  final _offerMaxCtrl = TextEditingController();
  final _offerMinimumCtrl = TextEditingController();
  bool _offerEnabled = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(localDatabaseProvider).settings;
    _vipThresholdCtrl.text =
        (settings.get('customerVipThreshold') as num? ?? 10000).toString();
    _regularThresholdCtrl.text =
        (settings.get('customerRegularThreshold') as num? ?? 1000).toString();
    _offerEnabled =
        settings.get('loyaltyOfferEnabled', defaultValue: true) as bool;
    _offerPointsCtrl.text =
        (settings.get('loyaltyOfferPoints', defaultValue: 100) as num)
            .toString();
    _offerPercentCtrl.text =
        (settings.get('loyaltyOfferPercent', defaultValue: 5) as num)
            .toString();
    _offerMaxCtrl.text =
        (settings.get('loyaltyOfferMaxDiscount', defaultValue: 100) as num)
            .toString();
    _offerMinimumCtrl.text =
        (settings.get('loyaltyOfferMinimumPurchase', defaultValue: 0) as num)
            .toString();
    Future<void>(() async {
      try {
        final profile = await ref.read(shopProfileProvider.future);
        if (!mounted || profile == null) return;
        await settings.put('loyaltyOfferEnabled', profile.loyaltyOfferEnabled);
        await settings.put('loyaltyOfferPoints', profile.loyaltyOfferPoints);
        await settings.put('loyaltyOfferPercent', profile.loyaltyOfferPercent);
        await settings.put(
          'loyaltyOfferMaxDiscount',
          profile.loyaltyOfferMaxDiscount,
        );
        await settings.put(
          'loyaltyOfferMinimumPurchase',
          profile.loyaltyOfferMinimumPurchase,
        );
        ref.invalidate(loyaltyOfferProvider);
        setState(() {
          _offerEnabled = profile.loyaltyOfferEnabled;
          _offerPointsCtrl.text = '${profile.loyaltyOfferPoints}';
          _offerPercentCtrl.text = '${profile.loyaltyOfferPercent}';
          _offerMaxCtrl.text = '${profile.loyaltyOfferMaxDiscount}';
          _offerMinimumCtrl.text = '${profile.loyaltyOfferMinimumPurchase}';
        });
      } catch (_) {
        // Local settings remain the offline source of truth.
      }
    });
  }

  @override
  void dispose() {
    _vipThresholdCtrl.dispose();
    _regularThresholdCtrl.dispose();
    _offerPointsCtrl.dispose();
    _offerPercentCtrl.dispose();
    _offerMaxCtrl.dispose();
    _offerMinimumCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Theme(
      data: MohajonWarm.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(l10n.t('customerRulesTitle'))),
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: MohajonWarm.pageGradient),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _RulesCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF8B6F47,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.local_offer_rounded,
                              color: Color(0xFF8B6F47),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.t('autoTaggingRules'),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: Color(0xFF101828),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.t('autoTaggingDesc'),
                        style: TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _FieldLabel(label: l10n.t('vipThreshold')),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _vipThresholdCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: '10000',
                          prefixText: '৳ ',
                          helperText: l10n.t('vipThresholdHint'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _FieldLabel(label: l10n.t('regularThreshold')),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _regularThresholdCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: '1000',
                          prefixText: '৳ ',
                          helperText: l10n.t('regularThresholdHint'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF4E5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFFD29C)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: Color(0xFFF97316),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                l10n.t('autoTaggingNote'),
                                style: TextStyle(
                                  color: Color(0xFFB45309),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : _save,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            _isSaving
                                ? l10n.t('rulesSaving')
                                : l10n.t('saveRules'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _RulesCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _offerEnabled,
                        onChanged: (value) =>
                            setState(() => _offerEnabled = value),
                        title: Text(
                          l10n.t('loyaltyOfferSettingsTitle'),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(l10n.t('loyaltyOfferSettingsSubtitle')),
                      ),
                      const SizedBox(height: 8),
                      _FieldLabel(label: l10n.t('loyaltyOfferPointsLabel')),
                      TextFormField(
                        controller: _offerPointsCtrl,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      _FieldLabel(label: l10n.t('loyaltyOfferPercentLabel')),
                      TextFormField(
                        controller: _offerPercentCtrl,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      _FieldLabel(label: l10n.t('loyaltyOfferMaxLabel')),
                      TextFormField(
                        controller: _offerMaxCtrl,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      _FieldLabel(label: l10n.t('loyaltyOfferMinimumLabel')),
                      TextFormField(
                        controller: _offerMinimumCtrl,
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final vip = double.tryParse(_vipThresholdCtrl.text.trim());
    final regular = double.tryParse(_regularThresholdCtrl.text.trim());
    if (vip == null || vip < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).t('invalidVipThreshold')),
        ),
      );
      return;
    }
    if (regular == null || regular < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).t('invalidRegularThreshold'),
          ),
        ),
      );
      return;
    }
    final points = int.tryParse(_offerPointsCtrl.text.trim());
    final percent = double.tryParse(_offerPercentCtrl.text.trim());
    final maxDiscount = double.tryParse(_offerMaxCtrl.text.trim());
    final minimumPurchase = double.tryParse(_offerMinimumCtrl.text.trim());
    if (points == null ||
        points <= 0 ||
        percent == null ||
        percent < 0 ||
        percent > 100 ||
        maxDiscount == null ||
        maxDiscount < 0 ||
        minimumPurchase == null ||
        minimumPurchase < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).t('loyaltyOfferInvalid')),
        ),
      );
      return;
    }
    final settings = ref.read(localDatabaseProvider).settings;
    setState(() => _isSaving = true);
    try {
      await settings.put('customerVipThreshold', vip);
      await settings.put('customerRegularThreshold', regular);
      await settings.put('loyaltyOfferEnabled', _offerEnabled);
      await settings.put('loyaltyOfferPoints', points);
      await settings.put('loyaltyOfferPercent', percent);
      await settings.put('loyaltyOfferMaxDiscount', maxDiscount);
      await settings.put('loyaltyOfferMinimumPurchase', minimumPurchase);
      ref.invalidate(loyaltyOfferProvider);
      try {
        await ref
            .read(shopProfileServiceProvider)
            .updateLoyaltyOffer(
              enabled: _offerEnabled,
              pointsRequired: points,
              discountPercent: percent,
              maxDiscount: maxDiscount,
              minimumPurchase: minimumPurchase,
            );
      } catch (_) {
        // Preserve the local rule and retry when the owner saves again online.
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).t('rulesSaved')),
          backgroundColor: MohajonWarm.green,
        ),
      );
    }
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        color: MohajonWarm.ink,
        fontSize: 14,
      ),
    );
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: MohajonWarm.card.withValues(alpha: .94),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: MohajonWarm.goldBorder),
      boxShadow: const [
        BoxShadow(
          color: Color(0x12000000),
          blurRadius: 14,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: child,
  );
}
