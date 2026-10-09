import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/mohajon_warm_theme.dart';
import '../subscription_screen.dart';

/// Lock screen shown when the shop is in read-only mode (trial/subscription
/// expired). The shop owner can still view everything — this only blocks
/// creating new entries until they subscribe.
class PaywallSheet extends StatelessWidget {
  const PaywallSheet({super.key, this.requiredTier = 'PRO'});

  final String requiredTier;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isBusiness = requiredTier == 'BUSINESS';
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: MohajonWarm.muted.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFEDB3), Color(0xFFFFC64D)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_rounded,
              color: MohajonWarm.ink,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isBusiness ? l10n.t('businessPlanRequired') : l10n.t('proPlanRequired'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: MohajonWarm.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isBusiness ? l10n.t('businessPlanBody') : l10n.t('proPlanBody'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: MohajonWarm.muted,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _openSubscription(context);
              },
              style: FilledButton.styleFrom(
                backgroundColor: MohajonWarm.primary,
                foregroundColor: MohajonWarm.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.workspace_premium_rounded, size: 18),
              label: Text(
                l10n.t('subscribeNow'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isBusiness ? l10n.t('businessPlanHint') : l10n.t('proPlanHint'),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: MohajonWarm.goldText,
            ),
          ),
        ],
      ),
    );
  }

  void _openSubscription(BuildContext context) {
    // The sheet is popped first; now push the subscription screen.
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => const SubscriptionScreen(),
        settings: const RouteSettings(name: '/subscription'),
      ),
    );
  }
}
