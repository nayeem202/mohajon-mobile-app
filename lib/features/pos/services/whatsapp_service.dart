import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/sale.dart';
import '../../../core/models/customer.dart';

/// Builds WhatsApp messages (wa.me deep links) for bills and khata
/// reminders. Deep links are free — no server-side messaging costs.
class WhatsAppService {
  const WhatsAppService._();

  /// Normalizes a BD phone number to the international format wa.me
  /// expects (8801XXXXXXXXX, no +, no spaces).
  static String? normalizeBdPhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    // 01XXXXXXXXX -> 8801XXXXXXXXX
    if (digits.startsWith('01') && digits.length == 11) {
      digits = '880${digits.substring(1)}';
    }
    // 1XXXXXXXXX (missing leading 0) -> 8801XXXXXXXXX
    if (RegExp(r'^1\d{9}$').hasMatch(digits)) {
      digits = '880$digits';
    }
    // +88 01... stored with the 88 prefix already
    if (digits.startsWith('88') && !digits.startsWith('880')) {
      digits = '880${digits.substring(2)}';
    }
    final valid = RegExp(r'^8801\d{9}$').hasMatch(digits);
    return valid ? digits : null;
  }

  /// Opens WhatsApp with a pre-filled message. Returns false when there is
  /// no valid number or WhatsApp cannot be opened.
  static Future<bool> openChat({
    required String phone,
    required String message,
  }) async {
    final normalized = normalizeBdPhone(phone);
    if (normalized == null) return false;
    final encoded = Uri.encodeComponent(message);
    final uri = Uri.parse('https://wa.me/$normalized?text=$encoded');
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Bill message right after a sale. Includes shop name, items, totals and
  /// a thank-you line — everything the customer needs on WhatsApp.
  static String billMessage({
    required Sale sale,
    required String shopName,
    required String customerName,
    required String Function(String) t,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('*$shopName*');
    buffer.writeln('${t('whatsappBillTitle')} — ${_date(sale.createdAt)}');
    buffer.writeln('──────────────────');
    if (customerName.trim().isNotEmpty) {
      buffer.writeln('${t('customer')}: $customerName');
      buffer.writeln('──────────────────');
    }
    for (final item in sale.items) {
      final qty =
          item.qty % 1 == 0 ? item.qty.toStringAsFixed(0) : item.qty.toString();
      final lineTotal = (item.qty * item.unitPrice).toStringAsFixed(0);
      buffer.writeln(
        '• ${item.name} — $qty × ${item.unitPrice.toStringAsFixed(0)} = $lineTotal',
      );
    }
    buffer.writeln('──────────────────');
    if (sale.discount > 0) {
      buffer.writeln('${t('discount')}: -${sale.discount.toStringAsFixed(0)}');
    }
    buffer.writeln(
      '*${t('total')}: ${sale.totalAmount.toStringAsFixed(0)} ৳*',
    );
    if (sale.dueAmount > 0) {
      buffer.writeln('${t('paid')}: ${sale.paidAmount.toStringAsFixed(0)} ৳');
      buffer.writeln('*${t('due')}: ${sale.dueAmount.toStringAsFixed(0)} ৳*');
    } else {
      buffer.writeln('✅ ${t('whatsappFullyPaid')}');
    }
    buffer.writeln('──────────────────');
    buffer.writeln(t('whatsappThanksFooter'));
    return buffer.toString();
  }

  /// Khata (due) reminder message for a customer.
  static String dueReminderMessage({
    required Customer customer,
    required double dueAmount,
    required String shopName,
    required String Function(String) t,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('${t('whatsappGreeting')}, ${customer.name}!');
    buffer.writeln('──────────────────');
    buffer.writeln(
      '${t('whatsappDueLine1')} *$shopName* ${t('whatsappDueLine2')}',
    );
    buffer.writeln('──────────────────');
    buffer.writeln('*${t('due')}: ${dueAmount.toStringAsFixed(0)} ৳*');
    buffer.writeln('──────────────────');
    buffer.writeln(t('whatsappDueFooter'));
    return buffer.toString();
  }

  static String _date(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}
