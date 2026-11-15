import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_1/core/app/app_providers.dart';
import 'package:inventory_1/core/localization/app_localizations.dart';
import 'package:inventory_1/core/models/app_user.dart';
import 'package:inventory_1/core/services/sync_service.dart';
import 'package:inventory_1/features/notifications/providers/notification_providers.dart';
import 'package:inventory_1/features/settings/providers/shop_profile_providers.dart';
import 'package:inventory_1/features/profile/providers/profile_providers.dart';
import 'package:inventory_1/features/branches/providers/branch_providers.dart';
import 'package:inventory_1/features/accounting/providers/accounting_providers.dart';
import 'package:inventory_1/features/accounting/presentation/accounting_statement_screen.dart';
import 'package:inventory_1/features/accounting/presentation/accounting_setup_screen.dart';
import 'package:inventory_1/features/accounting/presentation/accounting_entry_screen.dart';
import 'package:inventory_1/features/accounting/presentation/accounting_workspace_screen.dart';
import 'package:inventory_1/features/accounting/presentation/accounting_journal_screen.dart';

final _state = <String, dynamic>{
  'configured': true,
  'startDate': '2026-10-01',
  'openingBalances': {'CASH': 100, 'CAPITAL': 100},
  'assets': [],
  'entries': [
    {
      'entryId': 'one',
      'entryType': 'CAPITAL_IN',
      'businessDate': '2026-10-02',
      'amount': 100,
      'note': 'A long owner contribution note for the business',
    },
  ],
  'issues': [
    {
      'code': 'CLASSIFICATION_REQUIRED',
      'sourceType': 'EXPENSE',
      'sourceId': 'sample',
      'amount': 10,
      'choices': ['OPERATING_EXPENSES', 'FIXED_ASSETS'],
    },
  ],
};
final _report = <String, dynamic>{
  'configured': true,
  'branchId': 'b',
  'from': '2026-10-01',
  'to': '2026-10-23',
  'asOf': '2026-10-23',
  'netProfit': 1234567.89,
  'totalAssets': 200,
  'totalLiabilities': 0,
  'totalEquity': 200,
  'difference': 0,
  'isBalanced': true,
  'assets': [
    {'account': 'CASH', 'amount': 200},
  ],
  'liabilities': [],
  'equity': [
    {'account': 'CAPITAL', 'amount': 200},
  ],
  'issues': [],
  '_cached': true,
};

class _QuietSync extends StateNotifier<SyncState> implements SyncController {
  _QuietSync() : super(const SyncState(phase: SyncPhase.idle));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _QuietNotifications extends StateNotifier<NotificationsState>
    implements NotificationsController {
  _QuietNotifications() : super(const NotificationsState(items: []));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final screens = <String, Widget>{
    'income': const AccountingStatementScreen(),
    'balance': const AccountingStatementScreen(balanceSheet: true),
    'opening': const AccountingSetupScreen(),
    'entry': const AccountingEntryScreen(),
    'opening_form': const AccountingSetupScreen(),
    'loan_repayment': const AccountingEntryScreen(
      initial: {'entryType': 'LOAN_REPAYMENT', 'amount': 20},
    ),
    'asset_depreciation': const AccountingEntryScreen(
      initial: {'entryType': 'DEPRECIATION', 'amount': 10},
    ),
    'workspace': const AccountingWorkspaceScreen(),
    'classification': AccountingClassificationScreen(
      issue: Map<String, dynamic>.from((_state['issues'] as List).first as Map),
    ),
    'journal': const AccountingJournalScreen(),
  };
  for (final language in ['bn', 'en']) {
    for (final screen in screens.entries) {
      testWidgets('${screen.key} fits 320dp and 2x $language text', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              syncStateProvider.overrideWith((ref) => _QuietSync()),
              notificationsProvider.overrideWith(
                (ref) => _QuietNotifications(),
              ),
              profileProvider.overrideWith((ref) => null),
              shopProfileProvider.overrideWith((ref) => Stream.value(null)),
              currentUserProvider.overrideWith(
                (ref) => AppUser(
                  userId: 'u',
                  phone: '0',
                  shopId: 's',
                  role: UserRole.owner,
                  updatedAt: DateTime(2026),
                ),
              ),
              currentBranchIdProvider.overrideWith((ref) => 'b'),
              branchesProvider.overrideWith((ref) async => []),
              accountingStateProvider.overrideWith(
                (ref) async => screen.key == 'opening_form'
                    ? {'configured': false}
                    : _state,
              ),
              accountingPendingProvider.overrideWith((ref) => []),
              accountingReportProvider.overrideWith(
                (ref, query) async => _report,
              ),
              accountingJournalProvider.overrideWith(
                (ref, query) async => {
                  'entries': [
                    {
                      'sourceType': 'SALE',
                      'sourceId': 'sale',
                      'businessDate': '2026-10-02',
                      'journalKind': 'POSTING',
                      'lines': [
                        {'account': 'SALES', 'debit': 0, 'credit': 100},
                      ],
                    },
                  ],
                },
              ),
            ],
            child: MaterialApp(
              locale: Locale(language),
              supportedLocales: const [Locale('en'), Locale('bn')],
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(2)),
                child: child!,
              ),
              home: screen.value,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final scroll = find.byType(Scrollable).first;
        // Visit the full page, not just the first lazy viewport.
        for (var i = 0; i < 14; i++) {
          await tester.drag(scroll, const Offset(0, -450));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        if (screen.key == 'entry') {
          final container = ProviderScope.containerOf(
            tester.element(find.byType(AccountingEntryScreen)),
          );
          container.read(currentBranchIdProvider.notifier).state =
              'another-branch';
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('accounting-entry-amount')),
            findsNothing,
          );
          expect(
            find.text(AppLocalizations(Locale(language)).t('acctScopeChanged')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
