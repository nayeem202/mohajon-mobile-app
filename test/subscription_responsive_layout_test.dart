import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_1/core/localization/app_localizations.dart';
import 'package:inventory_1/features/subscription/models/subscription_models.dart';
import 'package:inventory_1/features/subscription/presentation/subscription_screen.dart';
import 'package:inventory_1/features/subscription/providers/subscription_providers.dart';

void main() {
  testWidgets('subscription cards fit narrow widths in both app languages', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final language in const ['en', 'bn']) {
      for (final width in const [280.0, 320.0, 360.0]) {
        await tester.binding.setSurfaceSize(Size(width, 760));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              subscriptionPlansProvider.overrideWith(
                (ref) async => const [
                  SubscriptionPlan(
                    planCode: 'PRO_YEARLY',
                    name: 'Professional plan',
                    description:
                        'Advanced reports, inventory management, business insights and customer support',
                    priceBdt: 2999,
                    durationDays: 365,
                    isActive: true,
                    tier: 'PRO',
                  ),
                ],
              ),
              subscriptionStatusProvider.overrideWith(
                (ref) async => const SubscriptionInfo(
                  hasActive: true,
                  status: 'ACTIVE',
                  planCode: 'PRO_YEARLY',
                  planName: 'Professional',
                  daysRemaining: 27,
                  tier: 'PRO',
                ),
              ),
              aiCreditStatusProvider.overrideWith(
                (ref) async => const AiCreditStatus(
                  monthlyLimit: 100,
                  monthlyUsed: 50,
                  monthlyRemaining: 50,
                  welcomeRemaining: 5,
                  remaining: 55,
                ),
              ),
            ],
            child: MaterialApp(
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
                ).copyWith(textScaler: const TextScaler.linear(1.2)),
                child: child!,
              ),
              home: const SubscriptionScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: '$language at $width px',
        );
      }
    }
  });
}
