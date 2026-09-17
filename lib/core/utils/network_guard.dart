import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';

/// Returns true if the device has any active network (WiFi/mobile data).
Future<bool> isConnected() async {
  try {
    final results = await Connectivity().checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  } catch (_) {
    return false;
  }
}

/// Guard for features that require internet access.
///
/// If the device is online the [action] runs immediately. Otherwise a
/// bilingual message ("No internet connection… retry") is shown with a
/// Retry action; retry re-checks connectivity and only runs the action when
/// the device is back online — otherwise the same message appears again.
Future<void> requireInternetFor(
  BuildContext context,
  Future<void> Function() action,
) async {
  final l10n = AppLocalizations.of(context);
  final message = l10n.t('noInternetMessage');
  final retryLabel = l10n.t('retry');
  if (await isConnected()) {
    if (!context.mounted) return;
    await action();
    return;
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: retryLabel,
          textColor: Colors.white,
          onPressed: () => requireInternetFor(context, action),
        ),
      ),
    );
}