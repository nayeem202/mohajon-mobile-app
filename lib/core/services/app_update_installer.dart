import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_update_policy.dart';

final appUpdateInstallerProvider = Provider((ref) => AppUpdateInstaller());

enum UpdateLaunchResult { started, cancelled, storeOpened, failed }

class AppUpdateInstaller {
  AppUpdateInstaller({
    this.checkPlay = InAppUpdate.checkForUpdate,
    this.performImmediate = InAppUpdate.performImmediateUpdate,
    Future<bool> Function(Uri)? openExternal,
  }) : openExternal = openExternal ?? _openExternal;

  final Future<AppUpdateInfo> Function() checkPlay;
  final Future<AppUpdateResult> Function() performImmediate;
  final Future<bool> Function(Uri) openExternal;

  static Future<bool> _openExternal(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  Future<UpdateLaunchResult> launch(AppUpdateDecision decision) async {
    final installed = decision.installed;
    if (!decision.updateRequired || installed == null) {
      return UpdateLaunchResult.failed;
    }
    if (installed.platform == 'android') {
      try {
        final info = await checkPlay().timeout(const Duration(seconds: 4));
        final inProgress =
            info.updateAvailability ==
            UpdateAvailability.developerTriggeredUpdateInProgress;
        final available =
            info.updateAvailability == UpdateAvailability.updateAvailable &&
            info.immediateUpdateAllowed &&
            (info.availableVersionCode ?? 0) >=
                decision.policy!.minimumBuildNumber;
        if (info.packageName == installed.packageName &&
            (inProgress || available)) {
          final result = await performImmediate();
          if (result == AppUpdateResult.success) {
            return UpdateLaunchResult.started;
          }
          if (result == AppUpdateResult.userDeniedUpdate) {
            return UpdateLaunchResult.cancelled;
          }
        }
      } catch (_) {
        // Debug/sideloaded builds and devices without the Play API use the
        // store listing. Never mark a version supported just for opening it.
      }
    }
    return _openStore(decision);
  }

  Future<UpdateLaunchResult?> resumeIfInProgress(
    AppUpdateDecision decision,
  ) async {
    if (!decision.updateRequired || decision.installed?.platform != 'android') {
      return null;
    }
    try {
      final info = await checkPlay().timeout(const Duration(seconds: 4));
      if (info.packageName == decision.installed!.packageName &&
          info.updateAvailability ==
              UpdateAvailability.developerTriggeredUpdateInProgress) {
        final result = await performImmediate();
        return switch (result) {
          AppUpdateResult.success => UpdateLaunchResult.started,
          AppUpdateResult.userDeniedUpdate => UpdateLaunchResult.cancelled,
          AppUpdateResult.inAppUpdateFailed => UpdateLaunchResult.failed,
        };
      }
    } catch (_) {
      // There is no Play update to resume on a local APK.
    }
    return null;
  }

  Future<UpdateLaunchResult> _openStore(AppUpdateDecision decision) async {
    final installed = decision.installed!;
    if (installed.platform == 'android') {
      // Use the real installed package, so a misconfigured link cannot send
      // this app's users to an unrelated Play listing.
      for (final uri in [
        Uri(
          scheme: 'market',
          host: 'details',
          queryParameters: {'id': installed.packageName},
        ),
        Uri.https('play.google.com', '/store/apps/details', {
          'id': installed.packageName,
        }),
      ]) {
        try {
          if (await openExternal(uri)) return UpdateLaunchResult.storeOpened;
        } catch (_) {
          // Try the HTTPS listing when the Play Store app is unavailable.
        }
      }
    } else {
      final uri = Uri.tryParse(decision.policy!.updateUrl);
      if (uri != null &&
          uri.scheme == 'https' &&
          uri.host == 'apps.apple.com') {
        try {
          if (await openExternal(uri)) return UpdateLaunchResult.storeOpened;
        } catch (_) {
          // Present a localized retry message rather than a platform error.
        }
      }
    }
    return UpdateLaunchResult.failed;
  }
}
