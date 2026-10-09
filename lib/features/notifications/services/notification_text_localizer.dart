import '../../../core/localization/app_localizations.dart';
import '../models/notification_model.dart';

/// Converts Mohajon's built-in notification templates at display time. Older
/// entries were persisted as English text, so this also gives existing local
/// and server history the language the user currently selected. Manually
/// written notifications deliberately remain untouched.
class NotificationTextLocalizer {
  const NotificationTextLocalizer._();

  static ({String title, String description}) resolve(
    AppNotification notification,
    AppLocalizations l10n,
  ) {
    final title = notification.title.trim().toLowerCase();
    final body = notification.description.trim();

    if (title == 'low stock alert') {
      final match = RegExp(
        r'^(.+?) has ([\d.]+) (.+) left\.$',
      ).firstMatch(body);
      return (
        title: l10n.t('lowStockAlert'),
        description: match == null
            ? body
            : l10n.tP('notificationLowStockMessage', {
                'product': match.group(1)!,
                'quantity': match.group(2)!,
                'unit': match.group(3)!,
              }),
      );
    }
    if (title == 'expense recorded') {
      final separator = body.lastIndexOf(':');
      return (
        title: l10n.t('notificationExpenseRecorded'),
        description: separator < 1
            ? body
            : l10n.tP('notificationExpenseRecordedMessage', {
                'category': body.substring(0, separator).trim(),
                'amount': body.substring(separator + 1).trim(),
              }),
      );
    }
    if (title == 'payment received') {
      final amount = _prefixBefore(body, ' payment recorded.');
      return (
        title: l10n.t('notificationPaymentReceived'),
        description: amount == null
            ? body
            : l10n.tP('notificationPaymentReceivedMessage', {'amount': amount}),
      );
    }
    if (title == 'vendor stock received') {
      final amount = _prefixBefore(body, ' purchase recorded from vendor.');
      return (
        title: l10n.t('notificationVendorStockReceived'),
        description: amount == null
            ? body
            : l10n.tP('notificationVendorStockReceivedMessage', {
                'amount': amount,
              }),
      );
    }
    if (title == 'vendor payment recorded') {
      final amount = _prefixBefore(body, ' vendor payment recorded.');
      return (
        title: l10n.t('notificationVendorPaymentRecorded'),
        description: amount == null
            ? body
            : l10n.tP('notificationVendorPaymentRecordedMessage', {
                'amount': amount,
              }),
      );
    }
    if (title == 'sale completed') {
      final amount = _prefixAfter(body, 'sale of ', ' recorded.');
      return (
        title: l10n.t('notificationSaleCompleted'),
        description: amount == null
            ? body
            : l10n.tP('notificationSaleCompletedMessage', {'amount': amount}),
      );
    }
    if (title == 'due payment reminder') {
      final match = RegExp(
        r'^(.+?) and more — (.+) due from (.+)$',
      ).firstMatch(body);
      return (
        title: l10n.t('notificationDueReminder'),
        description: match == null
            ? body
            : l10n.tP('notificationDueReminderMessage', {
                'product': match.group(1)!,
                'amount': match.group(2)!,
                'customer': match.group(3)!,
              }),
      );
    }
    if (title == 'mohajon business coach') {
      final normalizedBody = body.toLowerCase();
      if (normalizedBody ==
          'your daily business brief is ready. no urgent warning today.') {
        return (
          title: l10n.t('notificationBusinessCoach'),
          description: l10n.t('notificationBusinessCoachHealthy'),
        );
      }
      if (normalizedBody == 'your daily business brief is ready.') {
        return (
          title: l10n.t('notificationBusinessCoach'),
          description: l10n.t('notificationBusinessCoachReady'),
        );
      }
    }
    return (title: notification.title, description: notification.description);
  }

  static String? _prefixBefore(String value, String suffix) =>
      value.endsWith(suffix)
      ? value.substring(0, value.length - suffix.length)
      : null;

  static String? _prefixAfter(String value, String prefix, String suffix) {
    final normalized = value.toLowerCase();
    if (!normalized.startsWith(prefix) || !normalized.endsWith(suffix)) {
      return null;
    }
    return value.substring(prefix.length, value.length - suffix.length);
  }
}
