import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/mohajon_warm_theme.dart';
import '../../../../core/utils/snackbar.dart';
import '../../services/whatsapp_service.dart';

/// Bottom sheet shown right after a sale completes — the shop keeper can
/// print the thermal receipt, save it to the phone, send the bill on
/// WhatsApp, or just close.
class SaleSuccessSheet extends StatelessWidget {
  const SaleSuccessSheet({
    super.key,
    required this.onPrint,
    required this.onSave,
    this.whatsappPhone,
    required this.whatsappMessage,
    this.onDigitalInvoice,
  });

  final VoidCallback onPrint;
  final VoidCallback onSave;
  final String? whatsappPhone;
  final String whatsappMessage;
  final Future<void> Function()? onDigitalInvoice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: MohajonWarm.muted.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF34D399), Color(0xFF059669)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.t('saleCompleteTitle'),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: MohajonWarm.ink,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onPrint();
              },
              style: FilledButton.styleFrom(
                backgroundColor: MohajonWarm.ink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.print_rounded, size: 19),
              label: Text(
                l10n.t('printInvoice'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (onDigitalInvoice != null)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: onDigitalInvoice,
                icon: const Icon(Icons.link_rounded, size: 19),
                label: Text(
                  l10n.t('shareDigitalInvoice'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MohajonWarm.green,
                  side: const BorderSide(color: MohajonWarm.green),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          if (onDigitalInvoice != null) const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: onSave,
              style: OutlinedButton.styleFrom(
                foregroundColor: MohajonWarm.ink,
                side: const BorderSide(color: MohajonWarm.ink),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.download_rounded, size: 19),
              label: Text(
                l10n.t('saveReceipt'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: () async {
                final phone = whatsappPhone;
                if (phone == null || phone.isEmpty) {
                  showAppSnackBar(
                    context,
                    AppLocalizations.of(context).t('whatsappNoPhone'),
                    isError: true,
                  );
                  return;
                }
                final ok = await WhatsAppService.openChat(
                  phone: phone,
                  message: whatsappMessage,
                );
                if (!ok && context.mounted) {
                  showAppSnackBar(
                    context,
                    AppLocalizations.of(context).t('whatsappFailed'),
                    isError: true,
                  );
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.chat_rounded, size: 19),
              label: Text(
                l10n.t('sendBillOnWhatsapp'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              l10n.t('close'),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: MohajonWarm.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
