import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:inventory_1/core/models/app_update_policy.dart';
import 'package:inventory_1/core/services/app_update_installer.dart';
import 'package:pub_semver/pub_semver.dart';

void main() {
  final decision = AppUpdateDecision(
    installed: InstalledAppVersion(
      platform: 'android',
      packageName: 'com.mohajon.app',
      version: Version(1, 0, 0),
      buildNumber: 1,
    ),
    policy: AppUpdatePolicy(
      platform: 'android',
      forceUpdateEnabled: true,
      minimumVersion: Version(1, 1, 0),
      minimumBuildNumber: 2,
      latestVersion: Version(1, 1, 0),
      latestBuildNumber: 2,
      updateUrl: 'https://play.google.com/store/apps/details?id=com.other.app',
    ),
  );

  AppUpdateInfo info({
    UpdateAvailability availability = UpdateAvailability.updateAvailable,
    bool allowed = true,
    int availableBuild = 2,
  }) => AppUpdateInfo(
    updateAvailability: availability,
    immediateUpdateAllowed: allowed,
    immediateAllowedPreconditions: null,
    flexibleUpdateAllowed: false,
    flexibleAllowedPreconditions: null,
    availableVersionCode: availableBuild,
    installStatus: InstallStatus.unknown,
    packageName: 'com.mohajon.app',
    clientVersionStalenessDays: null,
    updatePriority: 5,
  );

  test(
    'Update starts the official immediate flow after the Play availability check',
    () async {
      var starts = 0;
      final opened = <Uri>[];
      final installer = AppUpdateInstaller(
        checkPlay: () async => info(),
        performImmediate: () async {
          starts++;
          return AppUpdateResult.success;
        },
        openExternal: (uri) async {
          opened.add(uri);
          return true;
        },
      );
      expect(await installer.launch(decision), UpdateLaunchResult.started);
      expect(starts, 1);
      expect(opened, isEmpty);
      expect(
        decision.updateRequired,
        isTrue,
        reason: 'Opening an updater is not an installed-version upgrade',
      );
    },
  );

  test(
    'user cancellation remains blocked without opening another consent flow',
    () async {
      var storeOpens = 0;
      final installer = AppUpdateInstaller(
        checkPlay: () async => info(),
        performImmediate: () async => AppUpdateResult.userDeniedUpdate,
        openExternal: (_) async {
          storeOpens++;
          return true;
        },
      );
      expect(await installer.launch(decision), UpdateLaunchResult.cancelled);
      expect(storeOpens, 0);
    },
  );

  test(
    'sideloaded builds fall back to the real installed package Play listing',
    () async {
      final opened = <Uri>[];
      final installer = AppUpdateInstaller(
        checkPlay: () async =>
            throw PlatformException(code: 'ERROR_API_NOT_AVAILABLE'),
        openExternal: (uri) async {
          opened.add(uri);
          return uri.scheme == 'https';
        },
      );
      expect(await installer.launch(decision), UpdateLaunchResult.storeOpened);
      expect(opened.map((uri) => uri.scheme), ['market', 'https']);
      expect(opened.last.host, 'play.google.com');
      expect(opened.last.queryParameters['id'], 'com.mohajon.app');
    },
  );

  test('does not start a Play build below the mandatory minimum', () async {
    var starts = 0;
    final installer = AppUpdateInstaller(
      checkPlay: () async => info(availableBuild: 1),
      performImmediate: () async {
        starts++;
        return AppUpdateResult.success;
      },
      openExternal: (_) async => true,
    );
    expect(await installer.launch(decision), UpdateLaunchResult.storeOpened);
    expect(starts, 0);
  });

  test(
    'resumes an interrupted immediate update but never auto-starts a new one',
    () async {
      var starts = 0;
      var availability = UpdateAvailability.updateAvailable;
      final installer = AppUpdateInstaller(
        checkPlay: () async => info(availability: availability),
        performImmediate: () async {
          starts++;
          return AppUpdateResult.success;
        },
      );
      expect(await installer.resumeIfInProgress(decision), isNull);
      expect(starts, 0);
      availability = UpdateAvailability.developerTriggeredUpdateInProgress;
      expect(
        await installer.resumeIfInProgress(decision),
        UpdateLaunchResult.started,
      );
      expect(starts, 1);
    },
  );
}
