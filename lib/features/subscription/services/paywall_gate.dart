import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/paywall_service.dart';
import '../presentation/widgets/paywall_sheet.dart';

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

  static bool isReadOnly(WidgetRef ref) =>
      ref.read(isReadOnlyProvider);

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

  static Future<void> showPaywallSheet(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const PaywallSheet(),
    );
  }
}
