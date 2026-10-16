import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_1/core/models/app_update_policy.dart';
import 'package:inventory_1/core/services/app_update_service.dart';
import 'package:pub_semver/pub_semver.dart';

void main() {
  InstalledAppVersion installed(String version, int build) =>
      InstalledAppVersion(
        platform: 'android',
        packageName: 'com.mohajon.app',
        version: Version.parse(version),
        buildNumber: build,
      );

  AppUpdatePolicy policy({
    bool enabled = true,
    String minimum = '1.9.0',
    int build = 3,
  }) => AppUpdatePolicy.fromJson({
    'platform': 'android',
    'forceUpdateEnabled': enabled,
    'minimumVersion': minimum,
    'minimumBuildNumber': build,
    'latestVersion': '1.10.0',
    'latestBuildNumber': 10,
    'updateUrl':
        'https://play.google.com/store/apps/details?id=com.mohajon.app',
    'messageEn': 'Update Mohajon',
    'messageBn': 'আপডেট করুন',
  });

  test(
    'version comparisons are numeric and same-version builds are respected',
    () {
      final release = policy();
      expect(release.requiresUpdate(installed('1.8.9', 100)), isTrue);
      expect(release.requiresUpdate(installed('1.9.0', 2)), isTrue);
      expect(release.requiresUpdate(installed('1.9.0', 3)), isFalse);
      expect(release.requiresUpdate(installed('1.10.0', 1)), isFalse);
      expect(release.requiresUpdate(installed('1.9.0-beta.1', 100)), isTrue);
      expect(
        policy(enabled: false).requiresUpdate(installed('1.0.0', 1)),
        isFalse,
      );
    },
  );

  test(
    'damaged policy cannot create a mandatory update with an unsafe URL',
    () {
      for (final url in [
        '',
        'javascript:alert(1)',
        'http://example.com',
        'https://example.com',
      ]) {
        expect(
          () => AppUpdatePolicy.fromJson({
            ...policy().toJson(),
            'updateUrl': url,
          }),
          throwsFormatException,
        );
      }
    },
  );

  test('policy cache preserves both languages and version thresholds', () {
    final release = AppUpdatePolicy.fromJson(policy().toJson());
    expect(release.messageBn, 'আপডেট করুন');
    expect(release.messageEn, 'Update Mohajon');
    expect(release.requiresUpdate(installed('1.9.0', 2)), isTrue);
  });

  AppUpdateService service({
    AppUpdatePolicy? cached,
    Future<AppUpdatePolicy> Function(String)? fetch,
    Future<void> Function(AppUpdatePolicy)? save,
  }) => AppUpdateService(
    loadInstalled: () async => installed('1.0.0', 1),
    readCached: (_) => cached,
    fetchPolicy: fetch ?? (_) async => throw StateError('Offline'),
    savePolicy: save ?? (_) async {},
  );

  test(
    'offline or server failure with no known policy allows offline shop access',
    () async {
      final decision = await service().check();
      expect(decision.updateRequired, isFalse);
      expect(decision.installed, isNotNull);
    },
  );

  test(
    'a cached mandatory requirement remains enforced when offline',
    () async {
      final decision = await service(cached: policy()).check();
      expect(decision.updateRequired, isTrue);
      expect(decision.fromCache, isTrue);
    },
  );

  test(
    'a server kill switch replaces a previously cached force update',
    () async {
      AppUpdatePolicy? saved;
      final decision = await service(
        cached: policy(),
        fetch: (_) async => policy(enabled: false),
        save: (value) async => saved = value,
      ).check();
      expect(decision.updateRequired, isFalse);
      expect(decision.fromCache, isFalse);
      expect(saved!.forceUpdateEnabled, isFalse);
    },
  );

  test(
    'cache-write failure does not discard a fresh mandatory policy',
    () async {
      final decision = await service(
        fetch: (_) async => policy(),
        save: (_) async => throw StateError('Disk full'),
      ).check();
      expect(decision.updateRequired, isTrue);
    },
  );

  test(
    'a policy for another platform cannot replace a cached Android policy',
    () async {
      final decision = await service(
        cached: policy(),
        fetch: (_) async => AppUpdatePolicy.fromJson({
          ...policy(enabled: false).toJson(),
          'platform': 'ios',
        }),
      ).check();
      expect(decision.updateRequired, isTrue);
      expect(decision.fromCache, isTrue);
    },
  );
}
