import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/pdf_doc.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/money.dart';
import '../../settings/providers/shop_profile_providers.dart';
import '../models/customer_ledger.dart';
import '../models/ledger_entry.dart';
import '../providers/report_providers.dart';
import '../services/ledger_excel_service.dart';
import '../services/ledger_pdf_service.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';

class CustomerLedgerDetailScreen extends ConsumerStatefulWidget {
  const CustomerLedgerDetailScreen({super.key, required this.customer});

  final CustomerLedger customer;

  @override
  ConsumerState<CustomerLedgerDetailScreen> createState() =>
      _CustomerLedgerDetailScreenState();
}

class _CustomerLedgerDetailScreenState
    extends ConsumerState<CustomerLedgerDetailScreen> {
  bool _exportingXlsx = false;
  bool _exportingPdf = false;

  CustomerLedger get customer => widget.customer;

  Future<void> _exportXlsx() async {
    if (_exportingXlsx) return;
    setState(() => _exportingXlsx = true);
    try {
      final entries =
          ref.read(customerLedgerDetailProvider(customer.customerId));
      if (entries.isEmpty) return;
      final l10n = AppLocalizations.of(context);
      final messenger = ScaffoldMessenger.of(context);
      final service = LedgerExcelService();
      await service.saveCustomerDetail(customer, entries);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.t('xlsxExported'))),
      );
    } finally {
      if (mounted) setState(() => _exportingXlsx = false);
    }
  }

  Future<void> _exportPdf() async {
    if (_exportingPdf) return;
    setState(() => _exportingPdf = true);
    try {
      final entries =
          ref.read(customerLedgerDetailProvider(customer.customerId));
      if (entries.isEmpty) return;
      final l10n = AppLocalizations.of(context);
      final messenger = ScaffoldMessenger.of(context);
      final service = LedgerPdfService();
      final company = DocCompany.fromShop(ref.read(shopProfileProvider).value);
      await service.saveCustomerDetail(customer, entries, company);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.t('pdfExported'))),
      );
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries =
        ref.watch(customerLedgerDetailProvider(customer.customerId));
    final l10n = AppLocalizations.of(context);
    final totalDebit =
        entries.fold<double>(0, (s, e) => s + e.debit);
    final totalCredit =
        entries.fold<double>(0, (s, e) => s + e.credit);
    final lastBalance =
        entries.isEmpty ? 0.0 : entries.last.balance;

    return Theme(
      data: MohajonWarm.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            customer.name,
            style: const TextStyle(
              color: MohajonWarm.ink,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          backgroundColor: MohajonWarm.primary,
          foregroundColor: MohajonWarm.ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: MohajonWarm.primary,
            statusBarIconBrightness: Brightness.dark,
          ),
          actions: const [
            NotificationBell(),
            SizedBox(width: 6),
            ShopAvatar(),
          ],
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: MohajonWarm.pageGradient),
          child: SafeArea(
            top: false,
            child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: _MiniCard(
                  label: l10n.t('opening'),
                  value: money(0),
                  valueColor: MohajonWarm.goldText,
                  icon: Icons.calendar_view_day_rounded,
                  accent: MohajonWarm.goldText,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniCard(
                  label: l10n.t('debitLabel'),
                  value: money(totalDebit),
                  valueColor: const Color(0xFFF97316),
                  icon: Icons.arrow_upward_rounded,
                  accent: const Color(0xFFF97316),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MiniCard(
                  label: l10n.t('creditLabel'),
                  value: money(totalCredit),
                  valueColor: const Color(0xFF059669),
                  icon: Icons.arrow_downward_rounded,
                  accent: const Color(0xFF059669),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniCard(
                  label: lastBalance < 0
                      ? l10n.t('advanceLabel')
                      : l10n.t('balanceHeader'),
                  value: money(lastBalance.abs()),
                  valueColor: lastBalance < 0
                      ? const Color(0xFFF97316)
                      : const Color(0xFF059669),
                  borderColor: lastBalance < 0
                      ? const Color(0xFFF97316)
                      : const Color(0xFF059669),
                  icon: Icons.account_balance_wallet_rounded,
                  accent: lastBalance < 0
                      ? const Color(0xFFF97316)
                      : const Color(0xFF059669),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _FullExportButton(
                  label: l10n.t('downloadXlsx'),
                  icon: Icons.table_chart_outlined,
                  color: const Color(0xFF059669),
                  isBusy: _exportingXlsx,
                  onTap: _exportXlsx,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FullExportButton(
                  label: l10n.t('downloadPdf'),
                  icon: Icons.picture_as_pdf_rounded,
                  color: const Color(0xFFF97316),
                  isBusy: _exportingPdf,
                  onTap: _exportPdf,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _LedgerSectionHeader(),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Center(
                child: Text(
                  l10n.t('noLedgerEntries'),
                  style: const TextStyle(
                    color: Color(0xFF98A2B3),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [MohajonWarm.card, Color(0xFFFFFBEF)],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: MohajonWarm.goldBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _headerRow(l10n),
                    ...entries.map((e) => _entryRow(e)),
                    _totalRow(totalDebit, totalCredit, lastBalance, l10n),
                  ],
                ),
              ),
            ),
        ],
        ),
        ),
        ),
      ),
    );
  }

  Widget _headerRow(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [MohajonWarm.primary, MohajonWarm.primarySoft],
        ),
        border: Border(
          bottom: BorderSide(color: MohajonWarm.goldBorder),
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(l10n.t('dateHeader'), style: _headerText)),
          SizedBox(
            width: 180,
            child: Text(l10n.t('particularsHeader'), style: _headerText),
          ),
          SizedBox(width: 80, child: Text(l10n.t('debitHeader'), style: _headerText)),
          SizedBox(width: 80, child: Text(l10n.t('creditHeader'), style: _headerText)),
          SizedBox(width: 80, child: Text(l10n.t('balanceHeader'), style: _headerText)),
        ],
      ),
    );
  }

  Widget _entryRow(LedgerEntry entry) {
    final dateStr = DateFormat('MMM d, y').format(entry.date);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFF0ECE4)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              dateStr,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            width: 180,
            child: Text(
              entry.particulars,
              style: const TextStyle(fontSize: 11),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              entry.debit > 0 ? money(entry.debit) : '',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFFF97316),
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              entry.credit > 0 ? money(entry.credit) : '',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF059669),
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              money(entry.balance),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: entry.balance == 0
                    ? const Color(0xFF101828)
                    : const Color(0xFFF97316),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(
      double debit, double credit, double balance, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: const BoxDecoration(
        color: MohajonWarm.tintYellow,
        border: Border(
          top: BorderSide(color: MohajonWarm.goldBorder),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 80, child: SizedBox.shrink()),
          SizedBox(
            width: 180,
            child: Text(
              l10n.t('totalHeader'),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              money(debit),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Color(0xFFF97316),
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              money(credit),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Color(0xFF059669),
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              money(balance),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Color(0xFF101828),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _headerText = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w800,
  color: MohajonWarm.ink,
);

class _LedgerSectionHeader extends StatelessWidget {
  const _LedgerSectionHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [MohajonWarm.primary, MohajonWarm.primarySoft],
            ),
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          child: const Icon(
            Icons.receipt_long_rounded,
            size: 15,
            color: MohajonWarm.ink,
          ),
        ),
        const SizedBox(width: 9),
        Text(
          AppLocalizations.of(context).t('drCrLedger'),
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.9,
            color: MohajonWarm.ink,
          ),
        ),
      ],
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.icon,
    required this.accent,
    this.borderColor,
  });

  final String label;
  final String value;
  final Color valueColor;
  final IconData icon;
  final Color accent;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final border = borderColor ?? MohajonWarm.goldBorder;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MohajonWarm.card, Color(0xFFFFFBEF)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: MohajonWarm.ink.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Stack(
          children: [
            Positioned(
              top: -18,
              right: -18,
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.1),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [accent, accent.withValues(alpha: 0.65)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.28),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(icon, size: 17, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: MohajonWarm.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: valueColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullExportButton extends StatelessWidget {
  const _FullExportButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isBusy = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool isBusy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: isBusy ? null : onTap,
      child: Opacity(
        opacity: isBusy ? 0.7 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isBusy)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              else ...[
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
