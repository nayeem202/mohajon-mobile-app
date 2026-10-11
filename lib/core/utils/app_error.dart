import 'package:flutter/foundation.dart';

import '../localization/app_localizations.dart';
import '../services/api_client.dart';
import '../services/auth_backend.dart';
import 'money.dart';

/// A validation failure whose amount must be presented in the selected app
/// language. Keeping the value separate prevents UI code from parsing an
/// English sentence just to translate it.
class CreditLimitExceededException implements Exception {
  const CreditLimitExceededException(this.availableCredit);

  final double availableCredit;
}

/// Logs the full technical error for developers and returns a short,
/// human-friendly message safe to show to the user.
String friendlyErrorMessage(
  Object error, {
  AppLocalizations? l10n,
  String? fallback,
}) {
  if (kDebugMode) debugPrint('APP_ERROR >>> ${error.runtimeType}: $error');
  final fallbackMessage =
      fallback ??
      _text(
        l10n,
        'errorSomethingWentWrong',
        'Something went wrong. Please try again.',
      );

  if (error is CreditLimitExceededException) {
    return _creditLimitMessage(l10n, error.availableCredit);
  }

  // Do not surface a backend's English sentence directly. The API code is a
  // stable contract; it lets every screen show one clear, selected-language
  // message while retaining technical details only in debug logs.
  if (error is ApiException) {
    final byCode = _apiCodeMessage(error, l10n);
    if (byCode != null) return byCode;
    if (error.statusCode == 401) {
      return _text(
        l10n,
        'errorSessionExpired',
        'Your session has expired. Please sign in again.',
      );
    }
    if (error.statusCode == 403) {
      return _text(
        l10n,
        'errorPermissionDenied',
        "You don't have permission to do this.",
      );
    }
    if (error.statusCode == 404) {
      return _text(
        l10n,
        'errorItemNotFound',
        'This item no longer exists on the server.',
      );
    }
    if (error.statusCode >= 500) {
      return _text(
        l10n,
        'errorServerUnavailable',
        'Server error. Please try again in a moment.',
      );
    }
    if (error.statusCode == 409) {
      return _text(l10n, 'errorAlreadyExists', 'This item already exists.');
    }
    return fallbackMessage;
  }

  if (error is AuthException) {
    if (_isSignInCancelled(error.message, error.code)) {
      return _text(
        l10n,
        'errorSignInCancelled',
        'Sign-in was cancelled. You can try again whenever you are ready.',
      );
    }
    final byCode = _authCodeMessage(error.code, l10n);
    if (byCode != null) return byCode;
    return fallbackMessage;
  }

  if (error is StateError) {
    final msg = error.message.trim();
    final translated = _stateErrorMessage(msg, l10n);
    if (translated != null) return translated;
    return fallbackMessage;
  }
  final s = error.toString().toLowerCase();
  if (_isSignInCancelled(s, s)) {
    return _text(
      l10n,
      'errorSignInCancelled',
      'Sign-in was cancelled. You can try again whenever you are ready.',
    );
  }
  if (s.contains('socketexception') ||
      s.contains('connection refused') ||
      s.contains('clientexception') ||
      s.contains('failed host lookup') ||
      s.contains('network is unreachable') ||
      s.contains('connection aborted') ||
      s.contains('connection reset')) {
    return _text(
      l10n,
      'errorNoInternet',
      "Can't reach the server. Check your internet connection and try again.",
    );
  }
  if (s.contains('timeout') || s.contains('timed out')) {
    return _text(
      l10n,
      'errorTimedOut',
      'The server took too long to respond. Please try again.',
    );
  }
  if (s.contains('401') || s.contains('unauthorized')) {
    return _text(
      l10n,
      'errorSessionExpired',
      'Your session has expired. Please sign in again.',
    );
  }
  if (s.contains('403') || s.contains('forbidden')) {
    return _text(
      l10n,
      'errorPermissionDenied',
      "You don't have permission to do this.",
    );
  }
  if (s.contains('404') || s.contains('not found')) {
    return _text(
      l10n,
      'errorItemNotFound',
      'This item no longer exists on the server.',
    );
  }
  if (s.contains('409') || s.contains('conflict') || s.contains('duplicate')) {
    return _text(l10n, 'errorAlreadyExists', 'This item already exists.');
  }
  if (s.contains('500') ||
      s.contains('502') ||
      s.contains('503') ||
      s.contains('internal server error')) {
    return _text(
      l10n,
      'errorServerUnavailable',
      'Server error. Please try again in a moment.',
    );
  }
  return fallbackMessage;
}

bool _isSignInCancelled(String message, String code) {
  final value = '$message $code'.toLowerCase();
  if (code.toLowerCase().contains('cancel')) return true;
  return value.contains('sign_in_canceled') ||
      value.contains('sign-in canceled') ||
      value.contains('sign in canceled') ||
      value.contains('sign_in_cancelled') ||
      value.contains('sign-in cancelled') ||
      value.contains('user_cancelled') ||
      value.contains('user canceled') ||
      value.contains('user cancelled') ||
      value.contains('canceled by user') ||
      value.contains('cancelled by user');
}

String? _authCodeMessage(String code, AppLocalizations? l10n) {
  switch (code.trim().toUpperCase()) {
    case 'INVALID_CREDENTIALS':
    case 'INVALID_RECOVERY':
      return _text(
        l10n,
        'errorInvalidCredentials',
        'Email or password is incorrect.',
      );
    case 'INVALID_OTP':
      return _text(
        l10n,
        'errorInvalidVerificationCode',
        'That verification code is incorrect or has expired. Request a new code and try again.',
      );
    case 'VERIFICATION_REQUIRED':
      return _text(
        l10n,
        'errorVerificationRequired',
        'Verify your email before signing in.',
      );
    case 'EMAIL_ALREADY_EXISTS':
      return _text(
        l10n,
        'errorEmailAlreadyExists',
        'An account already uses this email.',
      );
    case 'PHONE_ALREADY_EXISTS':
      return _text(
        l10n,
        'errorPhoneAlreadyExists',
        'An account already uses this phone number.',
      );
    case 'ACCOUNT_DISABLED':
    case 'ACCOUNT_LOCKED':
      return _text(
        l10n,
        'errorAccountUnavailable',
        'This account is temporarily unavailable. Contact support if you need help.',
      );
    case 'VERIFICATION_CODE_ACTIVE':
      return _text(
        l10n,
        'errorVerificationCodeActive',
        'A verification code was sent recently. Please wait before requesting another.',
      );
    case 'TOO_MANY_ATTEMPTS':
      return _text(
        l10n,
        'errorTooManyAttempts',
        'Too many attempts. Please wait a little and try again.',
      );
    case 'NO_RECOVERY_EMAIL':
      return _text(
        l10n,
        'errorNoRecoveryEmail',
        'No recovery email is available for this account. Contact support.',
      );
    case 'INVALID_CURRENT_PASSWORD':
      return _text(
        l10n,
        'errorInvalidCurrentPassword',
        'Your current password is incorrect.',
      );
  }
  return null;
}

String? _apiCodeMessage(ApiException error, AppLocalizations? l10n) {
  final normalizedCode = error.code.trim().toUpperCase();
  final authMessage = _authCodeMessage(normalizedCode, l10n);
  if (authMessage != null) return authMessage;
  switch (normalizedCode) {
    case 'CREDIT_LIMIT_EXCEEDED':
      return _creditLimitMessage(l10n, _availableCreditFrom(error.message));
    case 'INSUFFICIENT_STOCK':
      return _text(
        l10n,
        'errorInsufficientStock',
        'There is not enough stock to complete this sale.',
      );
    case 'INVALID_CREDENTIALS':
      return _text(
        l10n,
        'errorInvalidCredentials',
        'Email or password is incorrect.',
      );
    case 'VERIFICATION_REQUIRED':
      return _text(
        l10n,
        'errorVerificationRequired',
        'Verify your email before signing in.',
      );
    case 'INVALID_CURRENT_PASSWORD':
      return _text(
        l10n,
        'errorInvalidCurrentPassword',
        'Your current password is incorrect.',
      );
    case 'SUBSCRIPTION_REQUIRED':
      return _text(
        l10n,
        'errorSubscriptionRequired',
        'An active subscription is required for this action.',
      );
    case 'AI_UNAVAILABLE':
      return _text(
        l10n,
        'hambotAiError',
        'Could not reach the assistant right now. Check your connection and try again.',
      );
    case 'AI_QUOTA_EXCEEDED':
      return _text(
        l10n,
        'errorAiQuotaExceeded',
        'Your AI credits are finished. Upgrade or wait for the next monthly reset.',
      );
    case 'CONFLICT':
      return _text(l10n, 'errorAlreadyExists', 'This item already exists.');
  }
  return null;
}

String? _stateErrorMessage(String message, AppLocalizations? l10n) {
  final value = message.trim();
  final normalized = value.toLowerCase();
  if (normalized.contains('credit limit exceeded')) {
    return _creditLimitMessage(l10n, _availableCreditFrom(value));
  }
  if (normalized == 'cart is empty') {
    return _text(
      l10n,
      'errorCartEmpty',
      'Add at least one product to the cart.',
    );
  }
  if (normalized.contains('select a customer before saving a due sale')) {
    return _text(
      l10n,
      'errorCustomerRequiredForDue',
      'Select a customer before saving a due sale.',
    );
  }
  if (normalized.contains('sale total must be greater than zero')) {
    return _text(
      l10n,
      'errorSaleTotalInvalid',
      'Sale total must be greater than zero.',
    );
  }
  if (normalized.contains('payment cannot exceed the remaining due')) {
    return _text(
      l10n,
      'errorPaymentExceedsDue',
      'Payment cannot be more than the remaining due.',
    );
  }
  if (normalized.contains('no data in the selected period')) {
    return _text(
      l10n,
      'errorNoDataForPeriod',
      'No data found for the selected period.',
    );
  }
  if (normalized.contains('has expired and cannot be sold')) {
    return _text(
      l10n,
      'errorProductExpired',
      'This product has expired and cannot be sold.',
    );
  }
  if (normalized.contains('is no longer available')) {
    return _text(
      l10n,
      'errorProductUnavailable',
      'This product is no longer available.',
    );
  }
  if (normalized.contains('stock cannot become negative') ||
      normalized.contains('does not have enough stock') ||
      normalized.contains('stock is lower than product stock')) {
    return _text(
      l10n,
      'errorInsufficientStock',
      'There is not enough stock for this action.',
    );
  }
  if (normalized.contains('whole numbers')) {
    return _text(
      l10n,
      'wholeNumbersRequired',
      'Enter whole-number quantities.',
    );
  }
  if (normalized.contains('reason is required for damaged')) {
    return _text(
      l10n,
      'damageReasonRequired',
      'Add a short reason for damaged or rejected items.',
    );
  }
  if (normalized.contains('add a note explaining')) {
    return _text(
      l10n,
      'invoiceDifferenceNoteRequired',
      'Add a note explaining the invoice difference.',
    );
  }
  return null;
}

String _creditLimitMessage(AppLocalizations? l10n, double? availableCredit) {
  final amount = availableCredit == null ? null : money(availableCredit);
  if (amount == null) {
    return _text(
      l10n,
      'errorCreditLimitExceeded',
      'Customer credit limit has been reached.',
    );
  }
  if (l10n == null) {
    return 'Customer credit limit has been reached. Available credit: $amount.';
  }
  return l10n.tP('errorCreditLimitAvailable', {'amount': amount});
}

double? _availableCreditFrom(String message) {
  final match = RegExp(
    r'available(?:\s+credit)?\s*[:(]?\s*(?:৳|tk\.?|bdt)?\s*([\d,]+(?:\.\d+)?)',
    caseSensitive: false,
  ).firstMatch(message);
  return match == null
      ? null
      : double.tryParse(match.group(1)!.replaceAll(',', ''));
}

String _text(AppLocalizations? l10n, String key, String englishFallback) =>
    l10n?.t(key) ?? englishFallback;
