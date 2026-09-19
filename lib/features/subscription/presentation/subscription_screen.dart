import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/api_client.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/network_guard.dart';
import '../../../core/widgets/async_action_state.dart';
import '../models/subscription_models.dart';
import '../providers/subscription_providers.dart';
import 'bkash_payment_screen.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen>
    with AsyncActionState {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final plans = ref.watch(subscriptionPlansProvider);
    final status = ref.watch(subscriptionStatusProvider);

    return Theme(
      data: MohajonWarm.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: MohajonWarm.pageGradient),
          child: SafeArea(
            child: withLoadingOverlay(
              Column(
                children: [
                  _Header(onBack: () => Navigator.of(context).maybePop()),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        status.when(
                          data: (info) => _HeroBanner(
                            info: info,
                            onRenew: () => _startPurchase(info.planCode),
                            onResume: () => _startPurchase(info.planCode),
                            onUpgrade: () => _startPurchase(info.planCode),
                          ),
                          loading: () => const SizedBox(height: 8),
                          error: (_, _) => const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          l10n.t('chooseYourPlan').toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: MohajonWarm.muted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        plans.when(
                          data: (list) => Column(
                            children: [
                              for (final plan in list) ...[
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _buildPlanCard(plan, status),
                                ),
                              ],
                            ],
                          ),
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          error: (e, _) => _ErrorRetry(
                            message: _errorText(e, context),
                            onRetry: () =>
                                ref.invalidate(subscriptionPlansProvider),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _errorText(Object? error, BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (error is ApiException) return error.message;
    return l10n.t('couldNotLoadPlans');
  }

  Widget _buildPlanCard(
    SubscriptionPlan plan,
    AsyncValue<SubscriptionInfo> status,
  ) {
    final monthly = ref
        .watch(subscriptionPlansProvider)
        .value
        ?.where((p) => p.planCode == 'MONTHLY')
        .firstOrNull;
    final months = switch (plan.planCode) {
      'MONTHLY' => null,
      'SIX_MONTHS' => 6,
      'YEARLY' => 12,
      _ => null,
    };
    final savePct = monthly != null && months != null
        ? (((monthly.priceBdt * months) - plan.priceBdt) /
                  (monthly.priceBdt * months) *
                  100)
              .round()
              .clamp(0, 99)
        : 0;
    final isHighlight =
        status.hasValue && status.value?.planCode == plan.planCode;
    return _PlanCard(
      plan: plan,
      savePct: savePct,
      highlight: isHighlight,
      onSubscribe: () => _startPurchase(plan.planCode),
    );
  }

  Future<void> _startPurchase(String? planCode) async {
    if (planCode == null || planCode.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final online = await isConnected();
    if (!online) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.t('noInternetMessage')),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      return;
    }
    final service = ref.read(subscriptionApiServiceProvider);

    try {
      final result = await runBusyAction(() => service.purchase(planCode));
      if (!mounted || result == null) return;

      if (result.paymentStatus == 'SUCCESS') {
        // Server detected the earlier payment was already completed and
        // activated the subscription — no checkout needed.
        _refreshStatus();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('subscriptionActivated'))),
        );
        return;
      }

      final bkashUrl = result.bkashUrl;
      if (bkashUrl == null || bkashUrl.isEmpty) {
        // Backend could not produce a checkout URL (e.g. gateway unreachable).
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.t('paymentCouldNotStart'))));
        return;
      }

      await Navigator.of(context).push<BkashWebResult>(
        MaterialPageRoute(
          builder: (_) => BkashPaymentScreen(bkashUrl: bkashUrl),
        ),
      );

      if (!mounted) return;

      // When the WebView already popped itself with a terminal state, still
      // run the server-side confirmation — it is the source of truth.
      await _confirmPayment(result);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.t('paymentCouldNotStart'))));
    }
  }

  Future<void> _confirmPayment(SubscriptionPurchase purchase) async {
    final l10n = AppLocalizations.of(context);
    final service = ref.read(subscriptionApiServiceProvider);

    try {
      final confirmed = await runBusyAction(
        () => service.confirm(purchase.paymentId),
      );
      if (!mounted) return;

      ref.invalidate(subscriptionStatusProvider);
      ref.invalidate(subscriptionPlansProvider);

      if (confirmed == null) return;

      if (confirmed.isSuccess) {
        await _showResultDialog(confirmed);
      } else if (confirmed.paymentStatus == 'PENDING') {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.t('paymentPending'))));
      } else if (confirmed.paymentStatus == 'CANCELLED') {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.t('paymentCancelled'))));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              confirmed.errorMessage?.isNotEmpty == true
                  ? confirmed.errorMessage!
                  : l10n.t('paymentFailed'),
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.t('paymentFailed'))));
    }
  }

  Future<void> _showResultDialog(SubscriptionConfirm confirmed) async {
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.check_circle_rounded,
          color: MohajonWarm.goldText,
          size: 44,
        ),
        title: Text(l10n.t('subscriptionActivated')),
        content: Text(
          confirmed.endDate?.isNotEmpty == true
              ? l10n.tP('activePlanMessage', {
                  'plan': _planLabel(confirmed.planCode, context),
                  'date': _humanDate(confirmed.endDate),
                })
              : l10n.tP('activePlanNoDate', {
                  'plan': _planLabel(confirmed.planCode, context),
                }),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.t('ok')),
          ),
        ],
      ),
    );
    if (mounted) _refreshStatus();
  }

  void _refreshStatus() {
    ref.invalidate(subscriptionStatusProvider);
    ref.invalidate(subscriptionPlansProvider);
  }
}

String _planLabel(String planCode, BuildContext context) {
  final l10n = AppLocalizations.of(context);
  switch (planCode) {
    case 'MONTHLY':
      return l10n.t('monthlyPlan');
    case 'SIX_MONTHS':
      return l10n.t('sixMonthsPlan');
    case 'YEARLY':
      return l10n.t('yearlyPlan');
    default:
      return planCode;
  }
}

/// Formats a backend ISO timestamp into a short, human friendly
/// `dd MMM yyyy, hh:mm a` string (e.g. "12 Sep 2026, 02:30 PM").
String _humanDate(String? value) {
  if (value == null || value.isEmpty) return '';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final fixed = parsed.toLocal();
  return '${DateFormat('dd MMM yyyy').format(fixed)}, '
      '${DateFormat('hh:mm a').format(fixed)}';
}

/// Retro-style back header with the subscription branding.
class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
      child: Row(
        children: [
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(11),
            child: InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: onBack,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: MohajonWarm.goldBorder),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: MohajonWarm.ink,
                  size: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [MohajonWarm.primary, MohajonWarm.primaryPale],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.redeem_rounded,
              color: MohajonWarm.ink,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('subscription'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: MohajonWarm.ink,
                  ),
                ),
                Text(
                  l10n.t('manageYourPlan'),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF77735F),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Vibrant gradient banner that reflects the active / pending / cancelled /
/// no-plan state of the shop.
class _HeroBanner extends StatelessWidget {
  const _HeroBanner({
    required this.info,
    this.onRenew,
    this.onResume,
    this.onUpgrade,
  });

  final SubscriptionInfo info;
  final VoidCallback? onRenew;
  final VoidCallback? onResume;
  final VoidCallback? onUpgrade;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pending = info.status == 'PENDING';
    final cancelled = info.status == 'CANCELLED';

    final List<Color> gradient;
    final IconData icon;
    final String title;
    final String body;
    String? actionText;
    IconData actionIcon = Icons.arrow_forward_rounded;

    if (info.isTrialActive) {
      gradient = const [Color(0xFFFFEDB3), Color(0xFFFFC64D)];
      icon = Icons.redeem_rounded;
      title = l10n.t('trialActiveTitle');
      body = info.daysRemaining != null && info.endDate != null
          ? '${l10n.t('trialDaysLeft')} ${info.daysRemaining} • '
                '${l10n.t('expiresOn')} ${_humanDate(info.endDate)}'
          : l10n.t('trialActiveNotice');
      actionText = l10n.t('subscribeNow');
      actionIcon = Icons.arrow_forward_rounded;
    } else if (info.isActive) {
      gradient = const [Color(0xFFFFEDB3), Color(0xFFFFC64D)];
      icon = Icons.verified_rounded;
      title =
          '${info.planName ?? info.planCode ?? ''} '
          '${l10n.t('subscription')} ${l10n.t('isActive')}';
      body = info.daysRemaining != null && info.endDate != null
          ? '${l10n.t('daysRemaining')} ${info.daysRemaining} • '
                '${l10n.t('expiresOn')} ${_humanDate(info.endDate)}'
          : l10n.t('subscriptionActive');
      actionText = l10n.t('renew');
      actionIcon = Icons.refresh_rounded;
    } else if (pending) {
      gradient = const [Color(0xFFD97706), Color(0xFFF59E0B)];
      icon = Icons.schedule_rounded;
      title = l10n.t('paymentPending');
      body = l10n.t('pendingPaymentNotice');
      actionText = l10n.t('resumePayment');
      actionIcon = Icons.play_arrow_rounded;
    } else if (cancelled) {
      gradient = const [Color(0xFFEA580C), Color(0xFFF97316)];
      icon = Icons.cancel_outlined;
      title = l10n.t('paymentCancelled');
      body = l10n.t('paymentCancelledNotice');
      actionText = l10n.t('subscribeNow');
    } else {
      gradient = const [Color(0xFF8A6500), Color(0xFFB45309)];
      icon = Icons.lock_open_rounded;
      title = l10n.t('noActivePlan');
      body = l10n.t('noActivePlanNotice');
      actionText = l10n.t('subscribeNow');
    }

    final VoidCallback? action = info.isTrialActive
        ? onUpgrade
        : info.isActive
        ? onRenew
        : pending
        ? onResume
        : onUpgrade;

    final bool lightBg = info.isActive;
    final Color contentColor = lightBg ? MohajonWarm.ink : Colors.white;
    final Color contentMuted = lightBg ? const Color(0xFF6B5B1E) : Colors.white;

    final Widget? actionButton = action == null
        ? null
        : Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [MohajonWarm.primary, MohajonWarm.primaryPale],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.20),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: action,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: lightBg ? 10 : 14,
                    vertical: lightBg ? 7 : 9,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        actionText,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: MohajonWarm.ink,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Icon(
                        actionIcon,
                        size: lightBg ? 14 : 16,
                        color: MohajonWarm.ink,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: lightBg
                ? MohajonWarm.primary.withValues(alpha: 0.22)
                : gradient.last.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -22,
            top: -26,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: lightBg
                    ? MohajonWarm.ink.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 34,
            bottom: -46,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: lightBg
                    ? MohajonWarm.ink.withValues(alpha: 0.04)
                    : Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: lightBg ? 40 : 46,
                    height: lightBg ? 40 : 46,
                    decoration: BoxDecoration(
                      color: lightBg
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: lightBg
                            ? const Color(0xFFE0B84E)
                            : Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: contentColor,
                      size: lightBg ? 21 : 24,
                    ),
                  ),
                  if (lightBg) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: contentColor,
                        ),
                      ),
                    ),
                    if (actionButton != null) ...[
                      const SizedBox(width: 10),
                      actionButton,
                    ],
                  ] else ...[
                    const Spacer(),
                    ?actionButton,
                  ],
                ],
              ),
              if (!lightBg) ...[
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: contentColor,
                  ),
                ),
              ],
              const SizedBox(height: 3),
              Text(
                body,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: contentMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Warm plan tile using the brand gold/bronze accents — the original plan
/// design. The current (active) plan gets a stronger gold border.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.onSubscribe,
    this.highlight = false,
    this.savePct = 0,
  });

  final SubscriptionPlan plan;
  final VoidCallback onSubscribe;
  final bool highlight;
  final int savePct;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isPopular = plan.planCode == 'SIX_MONTHS';

    final (Color badgeColor, String? badgeText) = highlight
        ? (MohajonWarm.goldText, l10n.t('currentPlan'))
        : savePct > 0
        ? (MohajonWarm.goldText, l10n.tP('save', {'pct': '$savePct'}))
        : isPopular
        ? (MohajonWarm.orange, l10n.t('mostPopular'))
        : (MohajonWarm.goldText, null);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MohajonWarm.goldBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: MohajonWarm.ink.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: MohajonWarm.tintYellow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFFB45309),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: MohajonWarm.ink,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      l10n.tP('billedFor', {
                        'duration': _durationLabel(plan.durationDays, context),
                      }),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: MohajonWarm.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _GoldButton(
                label: l10n.t(highlight ? 'renew' : 'subscribe'),
                onPressed: onSubscribe,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF3ECDA)),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                money(plan.priceBdt),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: MohajonWarm.ink,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.tP('perDay', {
                    'amount': money(plan.priceBdt / plan.durationDays),
                  }),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: MohajonWarm.muted,
                  ),
                ),
              ),
              _Badge(color: badgeColor, label: badgeText),
            ],
          ),
          const SizedBox(height: 14),
          _FeatureTile(
            icon: Icons.check_circle_rounded,
            label: l10n.t('featureAllAccess'),
          ),
          const SizedBox(height: 8),
          _FeatureTile(
            icon: Icons.check_circle_rounded,
            label: l10n.t('featureBkash'),
          ),
          const SizedBox(height: 8),
          _FeatureTile(
            icon: Icons.check_circle_rounded,
            label: l10n.t('featureSupport'),
          ),
        ],
      ),
    );
  }

  String _durationLabel(int days, BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (days <= 31) return l10n.t('monthlyPlan');
    if (days <= 183) return l10n.t('sixMonthsPlan');
    return l10n.t('yearlyPlan');
  }
}

/// Compact gold gradient button used as the premium Subscribe / Renew action
/// on the plan cards.
class _GoldButton extends StatelessWidget {
  const _GoldButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MohajonWarm.primary, MohajonWarm.primaryPale],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: MohajonWarm.goldText.withValues(alpha: 0.30),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                    color: MohajonWarm.ink,
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 15,
                  color: MohajonWarm.ink,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small tinted pill used for plan badges (current / save / popular).
class _Badge extends StatelessWidget {
  const _Badge({required this.color, this.label});

  final Color color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final text = label;
    if (text == null) return const SizedBox(width: 8);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: MohajonWarm.goldText),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: MohajonWarm.ink,
          ),
        ),
      ],
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MohajonWarm.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: MohajonWarm.red, size: 32),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: MohajonWarm.muted),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: Text(l10n.t('retry'))),
        ],
      ),
    );
  }
}
