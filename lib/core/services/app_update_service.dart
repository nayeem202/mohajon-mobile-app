import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';

import '../app/app_providers.dart';
import '../models/app_update_policy.dart';
import 'api_client.dart';

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  final settings = ref.read(localDatabaseProvider).settings;
  final api = ApiClient(ref.read(localDatabaseProvider));
  return AppUpdateService(
    loadInstalled: () async {
      if (kIsWeb ||
          ![
            TargetPlatform.android,
            TargetPlatform.iOS,
          ].contains(defaultTargetPlatform)) {
        return null;
      }
      final package = await PackageInfo.fromPlatform();
      return InstalledAppVersion(
        platform: defaultTargetPlatform == TargetPlatform.android
            ? 'android'
            : 'ios',
        packageName: package.packageName,
        version: Version.parse(package.version),
        buildNumber: int.parse(package.buildNumber),
      );
    },
    readCached: (platform) {
      final json = settings.get('app_update_policy_$platform');
      return json is Map
          ? AppUpdatePolicy.fromJson(Map<String, dynamic>.from(json))
          : null;
    },
    fetchPolicy: (platform) async => AppUpdatePolicy.fromJson(
      await api.get(
        '/api/v1/app-updates/policy',
        query: {'platform': platform},
        timeout: const Duration(milliseconds: 2500),
      ),
    ),
    savePolicy: (policy) =>
        settings.put('app_update_policy_${policy.platform}', policy.toJson()),
  );
});

/// Read only after authentication. Network failure never invents a new block;
/// a previously received mandatory policy continues to work offline.
class AppUpdateService {
  AppUpdateService({
    required this.loadInstalled,
    required this.readCached,
    required this.fetchPolicy,
    required this.savePolicy,
  });

  final Future<InstalledAppVersion?> Function() loadInstalled;
  final AppUpdatePolicy? Function(String platform) readCached;
  final Future<AppUpdatePolicy> Function(String platform) fetchPolicy;
  final Future<void> Function(AppUpdatePolicy policy) savePolicy;

  Future<AppUpdateDecision> check() async {
    InstalledAppVersion? installed;
    try {
      installed = await loadInstalled().timeout(const Duration(seconds: 1));
    } catch (_) {
      return const AppUpdateDecision();
    }
    if (installed == null) return const AppUpdateDecision();
    AppUpdatePolicy? policy;
    try {
      policy = readCached(installed.platform);
    } catch (_) {
      // A corrupt cache does not prevent the next successful policy fetch.
    }
    var fromCache = policy != null;
    try {
      final remote = await fetchPolicy(
        installed.platform,
      ).timeout(const Duration(milliseconds: 2500));
      if (remote.platform != installed.platform) {
        throw const FormatException('Platform does not match');
      }
      policy = remote;
      fromCache = false;
      try {
        await savePolicy(remote);
      } catch (_) {
        // A storage failure must not discard a valid server requirement.
      }
    } catch (_) {
      // Leave offline-first shop operations usable when no policy is known.
    }
    return AppUpdateDecision(
      installed: installed,
      policy: policy,
      fromCache: fromCache,
    );
  }
}
