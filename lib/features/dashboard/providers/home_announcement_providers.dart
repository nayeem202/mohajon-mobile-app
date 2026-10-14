import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/services/api_client.dart';

class HomeAnnouncement {
  const HomeAnnouncement({
    required this.id,
    required this.title,
    required this.body,
    required this.titleBn,
    required this.bodyBn,
    required this.imageUrl,
    required this.createdAt,
    required this.expiresAt,
  });

  final String id;
  final String title;
  final String body;
  final String? titleBn;
  final String? bodyBn;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime? expiresAt;

  factory HomeAnnouncement.fromJson(Map<dynamic, dynamic> json) {
    String? optionalText(String key) {
      final value = json[key]?.toString().trim();
      return value == null || value.isEmpty ? null : value;
    }

    return HomeAnnouncement(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['description']?.toString() ?? '',
      titleBn: optionalText('titleBn'),
      bodyBn: optionalText('descriptionBn'),
      imageUrl: optionalText('imageUrl'),
      createdAt:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      expiresAt: DateTime.tryParse(json['expiresAt']?.toString() ?? ''),
    );
  }

  String localizedTitle(String languageCode) =>
      languageCode == 'bn' && titleBn != null ? titleBn! : title;

  String localizedBody(String languageCode) =>
      languageCode == 'bn' && bodyBn != null ? bodyBn! : body;
}

/// Fetch active platform announcements for the post-login dialog. The endpoint
/// returns only unexpired announcements and is separate from notification history.
final homeAnnouncementsProvider = FutureProvider<List<HomeAnnouncement>>((
  ref,
) async {
  final data = await ApiClient(
    ref.watch(localDatabaseProvider),
  ).getJson('/api/v1/notifications/home');
  if (data is! List) return const [];
  return data
      .whereType<Map>()
      .map(HomeAnnouncement.fromJson)
      .where((item) => item.id.isNotEmpty)
      .toList();
});
