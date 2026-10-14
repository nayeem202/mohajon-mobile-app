import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_1/features/dashboard/providers/home_announcement_providers.dart';

void main() {
  test('parses bilingual announcement content and its expiry timestamp', () {
    final announcement = HomeAnnouncement.fromJson({
      'id': 'announcement-1',
      'title': 'Store update',
      'description': 'Please review the latest update.',
      'titleBn': 'দোকানের আপডেট',
      'descriptionBn': 'সর্বশেষ আপডেটটি দেখুন।',
      'timestamp': '2026-10-12T10:00:00Z',
      'expiresAt': '2026-10-15T10:00:00Z',
    });

    expect(announcement.localizedTitle('bn'), 'দোকানের আপডেট');
    expect(announcement.localizedBody('bn'), 'সর্বশেষ আপডেটটি দেখুন।');
    expect(announcement.expiresAt, DateTime.parse('2026-10-15T10:00:00Z'));
  });

  test('missing expiry is not treated as an active announcement', () {
    final announcement = HomeAnnouncement.fromJson({
      'id': 'announcement-legacy',
      'title': 'Old announcement',
      'description': '',
    });

    expect(announcement.expiresAt, isNull);
  });
}
