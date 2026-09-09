import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/pdf_doc.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/money.dart';
import '../../settings/providers/shop_profile_providers.dart';
import '../models/customer_ledger.dart';
import '../providers/report_providers.dart';
import '../services/ledger_excel_service.dart';
import '../services/ledger_pdf_service.dart';
import 'customer_ledger_detail_screen.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';

class CustomerLedgerScreen extends ConsumerStatefulWidget {
  const CustomerLedgerScreen({super.key});

  @override
  ConsumerState<CustomerLedgerScreen> createState() =>
      _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState
    extends ConsumerState<CustomerLedgerScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _exportingXlsx = false;
  bool _exportingPdf = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _exportXlsx() async {
    if (_exportingXlsx) return;
    setState(() => _exportingXlsx = true);
    try {
      final all = ref.read(customerLedgerListProvider);
      if (all.isEmpty) return;
      final l10n = AppLocalizations.of(context);
      final messenger = ScaffoldMessenger.of(context);
      final service = LedgerExcelService();
      await service.saveAllCustomers(all);
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
      final all = ref.read(customerLedgerListProvider);
      if (all.isEmpty) return;
      final l10n = AppLocalizations.of(context);
      final messenger = ScaffoldMessenger.of(context);
      final service = LedgerPdfService();
      final company = DocCompany.fromShop(ref.read(shopProfileProvider).value);
      await service.saveAllCustomers(all, company);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.t('pdfExported'))),
      );
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(customerLedgerListProvider);
    final l10n = AppLocalizations.of(context);
    final customers = _query.isEmpty
        ? all
        : all
            .where((c) =>
                c.name.toLowerCase().contains(_query.toLowerCase()) ||
                c.phone.contains(_query))
            .toList();

    final outstanding = all.fold<double>(0, (s, c) => s + c.balance);
    final totalPaid = all.fold<double>(0, (s, c) => s + c.credit);
    final withDues = all.where((c) => c.hasDue).length;

    return Theme(
      data: MohajonWarm.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            l10n.t('reportCustomerLedger'),
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
                child: _SummaryCard(
                  label: l10n.t('outstanding'),
                  value: money(outstanding),
                  valueColor: const Color(0xFFF97316),
                  icon: Icons.account_balance_wallet_rounded,
                  accent: const Color(0xFFF97316),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryCard(
                  label: l10n.t('customers'),
                  value: '${all.length}',
                  valueColor: MohajonWarm.goldText,
                  icon: Icons.people_alt_rounded,
                  accent: MohajonWarm.goldText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: l10n.t('totalPaid'),
                  value: money(totalPaid),
                  valueColor: const Color(0xFFF97316),
                  icon: Icons.payments_rounded,
                  accent: const Color(0xFF059669),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryCard(
                  label: l10n.t('withDuesLabel'),
                  value: '$withDues',
                  valueColor: MohajonWarm.goldText,
                  icon: Icons.warning_amber_rounded,
                  accent: const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: l10n.t('searchCustomer'),
                      hintStyle: const TextStyle(
                        color: MohajonWarm.muted,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: MohajonWarm.goldText,
                      ),
                      filled: true,
                      fillColor: MohajonWarm.card.withValues(alpha: 0.7),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: MohajonWarm.goldBorder,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: MohajonWarm.goldText,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _ExportPill(
                label: 'XLSX',
                color: const Color(0xFF059669),
                isBusy: _exportingXlsx,
                onTap: _exportXlsx,
              ),
              const SizedBox(width: 6),
              _ExportPill(
                label: 'PDF',
                color: const Color(0xFFF97316),
                isBusy: _exportingPdf,
                onTap: _exportPdf,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.tP('xOfCustomers', {
              'a': '${customers.length}',
              'b': '${all.length}',
            }),
            style: const TextStyle(
              fontSize: 12,
              color: MohajonWarm.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (all.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Center(
                child: Text(
                  l10n.t('noCustomerData'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF98A2B3),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
          else
            ...customers.map((customer) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CustomerCard(
                    customer: customer,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            CustomerLedgerDetailScreen(customer: customer),
                      ),
                    ),
                  ),
                )),
        ],
        ),
        ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final Color valueColor;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MohajonWarm.card, Color(0xFFFFFBEF)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MohajonWarm.goldBorder),
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
                      fontSize: 17,
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

class _ExportPill extends StatelessWidget {
  const _ExportPill({
    required this.label,
    required this.color,
    required this.onTap,
    this.isBusy = false,
  });

  final String label;
  final Color color;
  final bool isBusy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: isBusy ? null : onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: isBusy ? 0.06 : 0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: isBusy
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer, required this.onTap});

  final CustomerLedger customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = customer.status;
    final isDue = status == LedgerStatus.due;
    final isAdvance = status == LedgerStatus.advance;
    final badgeBg = isAdvance
        ? const Color(0xFFFEF3C7)
        : isDue
            ? const Color(0xFFFFF1F2)
            : const Color(0xFFE4F6E9);
    final badgeFg = isAdvance
        ? const Color(0xFFB45309)
        : isDue
            ? const Color(0xFFEF4444)
            : const Color(0xFF059669);
    final badgeLabel = isAdvance
        ? l10n.tP('advanceBadge', {'amount': money(customer.absoluteBalance)})
        : isDue
            ? l10n.tP('dueBadge', {'amount': money(customer.balance)})
            : l10n.t('settled');
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MohajonWarm.card, Color(0xFFFFFBEF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MohajonWarm.goldBorder),
        boxShadow: [
          BoxShadow(
            color: MohajonWarm.ink.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          MohajonWarm.primary,
                          MohajonWarm.primarySoft,
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: MohajonWarm.goldText.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      customer.name[0].toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: MohajonWarm.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: MohajonWarm.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          customer.phone,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF667085),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badgeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: badgeFg,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF98A2B3),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.t('debitDr'),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF98A2B3),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          money(customer.debit),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFF97316),
                          ),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: customer.debitFraction.clamp(0, 1),
                            minHeight: 6,
                            backgroundColor: const Color(0xFFFFE4BF),
                            valueColor:
                                const AlwaysStoppedAnimation<Color>(
                              Color(0xFFF97316),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.t('creditCr'),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF98A2B3),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          money(customer.credit),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF059669),
                          ),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: customer.creditFraction.clamp(0, 1),
                            minHeight: 6,
                            backgroundColor: const Color(0xFFD1FAE5),
                            valueColor:
                                const AlwaysStoppedAnimation<Color>(
                              Color(0xFF059669),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
