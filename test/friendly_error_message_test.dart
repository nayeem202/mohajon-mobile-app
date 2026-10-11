import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_1/core/localization/app_localizations.dart';
import 'package:inventory_1/core/services/api_client.dart';
import 'package:inventory_1/core/services/auth_backend.dart';
import 'package:inventory_1/core/utils/app_error.dart';

void main() {
  test('does not expose arbitrary backend text, even without localization', () {
    const secret = 'db.internal.company:5432 stack trace';
    expect(
      friendlyErrorMessage(const ApiException(500, 'INTERNAL', secret)),
      isNot(contains(secret)),
    );
    expect(friendlyErrorMessage(StateError(secret)), isNot(contains(secret)));
  });

  test('maps backend failures to selected-language friendly copy', () {
    final bangla = AppLocalizations(const Locale('bn'));
    final message = friendlyErrorMessage(
      const ApiException(503, 'SERVICE_UNAVAILABLE', 'upstream host leaked'),
      l10n: bangla,
    );
    expect(message, contains('সার্ভারে'));
    expect(message, isNot(contains('upstream host leaked')));
  });

  test('maps provider cancellation as a non-technical sign-in message', () {
    final english = AppLocalizations(const Locale('en'));
    expect(
      friendlyErrorMessage(
        const AuthException(
          'Google sign-in failed: canceled',
          code: 'canceled',
        ),
        l10n: english,
      ),
      contains('Sign-in was cancelled'),
    );
  });
}
