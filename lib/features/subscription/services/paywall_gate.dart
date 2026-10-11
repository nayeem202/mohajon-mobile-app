import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/app_error.dart';
import '../../../core/utils/snackbar.dart';
import '../services/paywall_service.dart';
import '../presentation/widgets/paywall_sheet.dart';
import '../providers/subscription_providers.dart';

/// Central write-gate for the freemium model.
///
/// Usage at any write entry point:
///   onTap: () => PaywallGate.guard(context, ref, () {
///     // ... the actual write action
///   }),
///
/// When the shop is in read-only mode (trial/subscription expired) the
/// paywall sheet is shown instead of running the action. Full access and
/// offline-unknown states run the action directly.
class PaywallGate {
  PaywallGate._();

  static bool isReadOnly(WidgetRef ref) => ref.read(isReadOnlyProvider);

  static bool hasPro(WidgetRef ref) {
    final status = ref.read(subscriptionStatusProvider);
    return status.hasValue && (status.value?.hasPremium ?? false);
  }

  static bool hasBusiness(WidgetRef ref) {
    final status = ref.read(subscriptionStatusProvider);
    return status.hasValue && (status.value?.hasBusiness ?? false);
  }

  /// Waits for a verified (or valid offline-cached) subscription result.
  /// Synchronous checks incorrectly treat the provider's initial loading state
  /// as a definitive denial and can show a paywall on the first tap.
  static Future<bool> hasBusinessAsync(WidgetRef ref) async =>
      (await ref.read(subscriptionStatusProvider.future)).hasBusiness;

  /// Resolves Business access before opening or mutating a Business feature.
  /// A network/status failure is shown as an error, never as a false upgrade
  /// prompt. The failed provider is invalidated so a later tap can retry.
  static Future<bool> ensureBusinessAccess(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context);
    bool allowed;
    try {
      allowed = await hasBusinessAsync(ref);
    } catch (error) {
      ref.invalidate(subscriptionStatusProvider);
      if (context.mounted) {
        showAppSnackBar(
          context,
          friendlyErrorMessage(
            error,
            l10n: l10n,
            fallback: l10n.t('errorNoInternet'),
          ),
          isError: true,
        );
      }
      return false;
    }
    if (!context.mounted) return false;
    if (!allowed) {
      await showPaywallSheet(context, requiredTier: 'BUSINESS');
      return false;
    }
    return true;
  }

  /// Runs [action] only when the shop has full access; otherwise shows the
  /// paywall sheet.
  static void guard(BuildContext context, WidgetRef ref, VoidCallback action) {
    if (isReadOnly(ref)) {
      showPaywallSheet(context);
      return;
    }
    action();
  }

  /// Runs [action] only when allowed; for async flows (e.g. checkout) the
  /// same guard applies but the sheet is shown on the provided context.
  static Future<T?> guardAsync<T>(
    BuildContext context,
    WidgetRef ref,
    Future<T?> Function() action,
  ) async {
    if (isReadOnly(ref)) {
      await showPaywallSheet(context);
      return null;
    }
    return action();
  }

  static void guardPro(
    BuildContext context,
    WidgetRef ref,
    VoidCallback action,
  ) {
    if (!hasPro(ref)) {
      showPaywallSheet(context, requiredTier: 'PRO');
      return;
    }
    action();
  }

  static void guardBusiness(
    BuildContext context,
    WidgetRef ref,
    VoidCallback action,
  ) {
    if (!hasBusiness(ref)) {
      showPaywallSheet(context, requiredTier: 'BUSINESS');
      return;
    }
    action();
  }

  static Future<void> showPaywallSheet(
    BuildContext context, {
    String requiredTier = 'PRO',
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PaywallSheet(requiredTier: requiredTier),
    );
  }
}
