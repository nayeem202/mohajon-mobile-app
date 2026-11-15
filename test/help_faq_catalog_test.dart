import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_1/core/localization/app_localizations.dart';
import 'package:inventory_1/features/profile/data/help_faq_catalog.dart';

void main() {
  final entries = helpFaqTopics.expand((topic) => topic.entries).toList();

  test(
    'every FAQ topic and question has a unique stable ID and both languages',
    () {
      expect(
        helpFaqTopics.map((topic) => topic.id).toSet(),
        hasLength(helpFaqTopics.length),
      );
      expect(
        entries.map((entry) => entry.id).toSet(),
        hasLength(entries.length),
      );
      expect(entries.length, greaterThanOrEqualTo(80));
      for (final topic in helpFaqTopics) {
        expect(topic.entries, isNotEmpty, reason: topic.id);
        expect(topic.title('en'), isNotEmpty);
        expect(topic.title('bn'), matches(RegExp(r'[\u0980-\u09FF]')));
      }
      for (final entry in entries) {
        expect(entry.question('en'), isNotEmpty, reason: entry.id);
        expect(entry.answer('en').length, greaterThan(20), reason: entry.id);
        expect(
          entry.question('bn'),
          matches(RegExp(r'[\u0980-\u09FF]')),
          reason: entry.id,
        );
        expect(
          entry.answer('bn'),
          matches(RegExp(r'[\u0980-\u09FF]')),
          reason: entry.id,
        );
        expect(
          entry.question('en'),
          isNot(entry.question('bn')),
          reason: entry.id,
        );
        expect(entry.answer('en'), isNot(entry.answer('bn')), reason: entry.id);
      }
    },
  );

  test('catalogue covers all major app help areas', () {
    expect(helpFaqTopics.map((topic) => topic.id).toSet(), {
      'getting-started',
      'stock',
      'sales',
      'receipts',
      'customers',
      'suppliers',
      'reports',
      'team',
      'subscription',
      'ai',
      'offline',
      'security',
    });
    expect(
      entries.map((entry) => entry.id),
      containsAll([
        'register',
        'verification-email',
        'forgot-password',
        'social-login',
        'product-category',
        'units',
        'barcode',
        'expiry-batch',
        'stock-adjustment',
        'vat-discount',
        'sale-return',
        'collect-due',
        'customer-photo',
        'credit-limit',
        'purchase-stock',
        'partial-receipt',
        'supplier-return',
        'purchase-planner',
        'expenses',
        'day-closing',
        'report-export',
        'business-insights',
        'staff-access',
        'branches',
        'investors',
        'investor-payout',
        'subscription-payment',
        'ai-credits',
        'ai-language',
        'voice-billing',
        'sync-failed',
        'backup',
        'restore',
        'new-phone',
        'invoice-share',
        'app-lock',
        'device-access',
        'login-announcement',
        'force-update',
        'contact-support',
      ]),
    );
  });

  test(
    'search matches English and Bangla questions and answers in either UI language',
    () {
      for (final query in ['  BACKUP  ', 'ব্যাকআপ']) {
        final matches = helpFaqTopics.expand(
          (topic) => filterHelpFaqs(topic, query),
        );
        expect(matches.map((entry) => entry.id), contains('backup'));
      }
      final restore = entries.singleWhere((entry) => entry.id == 'restore');
      expect(restore.matches('compatible Mohajon'), isTrue);
      expect(restore.matches('সামঞ্জস্যপূর্ণ'), isTrue);
      expect(restore.matches('zz-nonexistent-term'), isFalse);
    },
  );

  test(
    'topic terms and multiple search words combine without losing results',
    () {
      final topic = helpFaqTopics.singleWhere((topic) => topic.id == 'offline');
      expect(
        filterHelpFaqs(topic, 'offline backup').map((entry) => entry.id),
        contains('backup'),
      );
      expect(filterHelpFaqs(topic, '  '), topic.entries);
      expect(filterHelpFaqs(topic, 'zz-no-such-topic'), isEmpty);
    },
  );

  test(
    'all FAQ controls are translated and have no unresolved placeholders',
    () {
      for (final language in ['bn', 'en']) {
        final l10n = AppLocalizations(Locale(language));
        for (final key in [
          'faqIntro',
          'faqSearchHint',
          'faqAllTopics',
          'faqClearSearch',
          'faqNoResults',
          'faqResetFilters',
        ]) {
          expect(l10n.t(key), isNot(key));
          if (language == 'bn') {
            expect(l10n.t(key), matches(RegExp(r'[\u0980-\u09FF]')));
          }
        }
        expect(
          l10n.tP('faqQuestionCount', {'count': '89'}),
          isNot(contains('{count}')),
        );
      }
    },
  );
}
