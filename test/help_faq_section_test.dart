import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_1/core/localization/app_localizations.dart';
import 'package:inventory_1/features/profile/data/help_faq_catalog.dart';
import 'package:inventory_1/features/profile/presentation/help_support_screen.dart';
import 'package:inventory_1/features/profile/presentation/widgets/help_faq_section.dart';

final _entries = helpFaqTopics.expand((topic) => topic.entries).toList();

void main() {
  for (final language in ['bn', 'en']) {
    testWidgets(
      'FAQ search, expansion, empty state and reset work in $language',
      (tester) async {
        await tester.pumpWidget(_app(language));
        await tester.pumpAndSettle();
        final search = find.byKey(const Key('help-faq-search'));
        await tester.enterText(search, 'independent backup');
        await tester.pumpAndSettle();
        final question = _entries.singleWhere((entry) => entry.id == 'backup');
        final tile = find.byKey(const Key('help-faq-entry-backup'));
        await tester.ensureVisible(tile);
        await tester.tap(find.text(question.question(language)));
        await tester.pumpAndSettle();
        expect(find.text(question.answer(language)), findsOneWidget);
        expect(
          find.text(question.answer(language == 'bn' ? 'en' : 'bn')),
          findsNothing,
        );

        await tester.ensureVisible(search);
        await tester.enterText(search, 'zz-no-such-faq');
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('help-faq-empty')), findsOneWidget);
        final reset = find.text(
          AppLocalizations(Locale(language)).t('faqResetFilters'),
        );
        await tester.ensureVisible(reset);
        await tester.tap(reset);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('help-faq-empty')), findsNothing);
        expect(tester.widget<TextField>(search).controller!.text, isEmpty);
        expect(
          find.byKey(const Key('help-faq-entry-register')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('topic filter can be selected and reset in $language', (
      tester,
    ) async {
      await tester.pumpWidget(_app(language));
      await tester.pumpAndSettle();
      final topic = find.byKey(const Key('help-faq-topic-stock'));
      await tester.ensureVisible(topic);
      await tester.tap(topic);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('help-faq-group-stock')), findsOneWidget);
      expect(find.byKey(const Key('help-faq-group-sales')), findsNothing);
      final all = find.byKey(const Key('help-faq-topic-all'));
      await tester.ensureVisible(all);
      await tester.tap(all);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('help-faq-group-sales')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'full help page and long FAQ fit 320dp with large $language text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(_app(language, fullPage: true, scale: 2));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final search = find.byKey(const Key('help-faq-search'));
        await tester.scrollUntilVisible(
          search,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(search, 'voice billing');
        await tester.pumpAndSettle();
        final tile = find.byKey(const Key('help-faq-entry-voice-billing'));
        await tester.ensureVisible(tile);
        await tester.tap(
          find.text(
            _entries
                .singleWhere((entry) => entry.id == 'voice-billing')
                .question(language),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'changing app language also translates a searched, expanded answer',
    (tester) async {
      await tester.pumpWidget(_app('en'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('help-faq-search')),
        'independent backup',
      );
      await tester.pumpAndSettle();
      final question = _entries.singleWhere((entry) => entry.id == 'backup');
      await tester.ensureVisible(
        find.byKey(const Key('help-faq-entry-backup')),
      );
      await tester.tap(find.text(question.questionEn));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_app('bn'));
      await tester.pumpAndSettle();
      expect(find.text(question.answerBn), findsOneWidget);
      expect(find.text(question.answerEn), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _app(String language, {bool fullPage = false, double scale = 1}) {
  return MaterialApp(
    locale: Locale(language),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: fullPage
        ? const HelpSupportScreen()
        : const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(18),
              child: HelpFaqSection(),
            ),
          ),
  );
}
