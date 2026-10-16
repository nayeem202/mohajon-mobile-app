import 'package:pub_semver/pub_semver.dart';

class InstalledAppVersion {
  const InstalledAppVersion({
    required this.platform,
    required this.packageName,
    required this.version,
    required this.buildNumber,
  });

  final String platform;
  final String packageName;
  final Version version;
  final int buildNumber;

  String get label => '$version ($buildNumber)';
}

class AppUpdatePolicy {
  const AppUpdatePolicy({
    required this.platform,
    required this.forceUpdateEnabled,
    required this.minimumVersion,
    required this.minimumBuildNumber,
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.updateUrl,
    this.messageEn = '',
    this.messageBn = '',
  });

  factory AppUpdatePolicy.fromJson(Map<String, dynamic> json) {
    final platform = json['platform'];
    final enabled = json['forceUpdateEnabled'];
    final minimumBuild = json['minimumBuildNumber'];
    final latestBuild = json['latestBuildNumber'];
    if (!['android', 'ios'].contains(platform) ||
        enabled is! bool ||
        minimumBuild is! int ||
        minimumBuild < 1 ||
        latestBuild is! int ||
        latestBuild < 1) {
      throw const FormatException('Invalid app update policy');
    }
    final minimum = Version.parse(json['minimumVersion'] as String);
    final latest = Version.parse(json['latestVersion'] as String);
    final url = (json['updateUrl'] as String? ?? '').trim();
    final uri = Uri.tryParse(url);
    if (latest < minimum ||
        (latest == minimum && latestBuild < minimumBuild) ||
        (enabled &&
            (uri == null ||
                uri.scheme != 'https' ||
                uri.host.isEmpty ||
                uri.userInfo.isNotEmpty ||
                uri.hasFragment ||
                (platform == 'android' &&
                    (uri.host != 'play.google.com' ||
                        uri.path != '/store/apps/details' ||
                        (uri.queryParameters['id'] ?? '').isEmpty)) ||
                (platform == 'ios' && uri.host != 'apps.apple.com')))) {
      throw const FormatException('Invalid app update release');
    }
    return AppUpdatePolicy(
      platform: platform as String,
      forceUpdateEnabled: enabled,
      minimumVersion: minimum,
      minimumBuildNumber: minimumBuild,
      latestVersion: latest,
      latestBuildNumber: latestBuild,
      updateUrl: url,
      messageEn: (json['messageEn'] as String? ?? '').trim(),
      messageBn: (json['messageBn'] as String? ?? '').trim(),
    );
  }

  final String platform;
  final bool forceUpdateEnabled;
  final Version minimumVersion;
  final int minimumBuildNumber;
  final Version latestVersion;
  final int latestBuildNumber;
  final String updateUrl;
  final String messageEn;
  final String messageBn;

  bool requiresUpdate(InstalledAppVersion installed) {
    if (!forceUpdateEnabled || installed.platform != platform) return false;
    final comparison = installed.version.compareTo(minimumVersion);
    return comparison < 0 ||
        (comparison == 0 && installed.buildNumber < minimumBuildNumber);
  }

  Map<String, dynamic> toJson() => {
    'platform': platform,
    'forceUpdateEnabled': forceUpdateEnabled,
    'minimumVersion': minimumVersion.toString(),
    'minimumBuildNumber': minimumBuildNumber,
    'latestVersion': latestVersion.toString(),
    'latestBuildNumber': latestBuildNumber,
    'updateUrl': updateUrl,
    'messageEn': messageEn,
    'messageBn': messageBn,
  };
}

class AppUpdateDecision {
  const AppUpdateDecision({
    this.installed,
    this.policy,
    this.fromCache = false,
  });

  final InstalledAppVersion? installed;
  final AppUpdatePolicy? policy;
  final bool fromCache;

  bool get updateRequired =>
      installed != null && (policy?.requiresUpdate(installed!) ?? false);
}
