import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/money.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _exportXlsx() async {
    final all = ref.read(customerLedgerListProvider);
    if (all.isEmpty) return;
    final service = LedgerExcelService();
    await service.saveAllCustomers(all);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('XLSX exported successfully')),
      );
    }
  }

  Future<void> _exportPdf() async {
    final all = ref.read(customerLedgerListProvider);
    if (all.isEmpty) return;
    final service = LedgerPdfService();
    await service.saveAllCustomers(all);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF exported successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(customerLedgerListProvider);
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
          title: const Text(
            'Customer Ledger',
            style: TextStyle(
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
                  label: 'Outstanding',
                  value: money(outstanding),
                  valueColor: const Color(0xFFF97316),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryCard(
                  label: 'Customers',
                  value: '${all.length}',
                  valueColor: const Color(0xFF101828),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: 'Total Paid',
                  value: money(totalPaid),
                  valueColor: const Color(0xFFF97316),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryCard(
                  label: 'With Dues',
                  value: '$withDues',
                  valueColor: const Color(0xFF101828),
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
                    decoration: const InputDecoration(
                      hintText: 'Search customer name',
                      prefixIcon: Icon(Icons.search_rounded, size: 20),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _ExportPill(
                label: 'XLSX',
                color: const Color(0xFF059669),
                onTap: _exportXlsx,
              ),
              const SizedBox(width: 6),
              _ExportPill(
                label: 'PDF',
                color: const Color(0xFFF97316),
                onTap: _exportPdf,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${customers.length} of ${all.length} customers',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF98A2B3),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          if (all.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(
                child: Text(
                  'No customer data yet.\nStart by adding customers and recording sales.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
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
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MohajonWarm.card, Color(0xFFFFFBEF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MohajonWarm.goldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: MohajonWarm.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportPill extends StatelessWidget {
  const _ExportPill({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Text(
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
    final settled = !customer.hasDue;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MohajonWarm.card, Color(0xFFFFFBEF)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MohajonWarm.goldBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: MohajonWarm.tintYellow,
                    child: Text(
                      customer.name[0].toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: MohajonWarm.goldText,
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
                            color: Color(0xFF101828),
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
                      color: settled
                          ? const Color(0xFFE4F6E9)
                          : const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      settled
                          ? 'Settled'
                          : 'Due ${money(customer.balance)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: settled
                            ? const Color(0xFF059669)
                            : const Color(0xFFEF4444),
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
                        const Text(
                          'Debit (Dr)',
                          style: TextStyle(
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
                        const Text(
                          'Credit (Cr)',
                          style: TextStyle(
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
