import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/money.dart';
import '../models/customer_ledger.dart';
import '../models/ledger_entry.dart';
import '../providers/report_providers.dart';
import '../services/ledger_excel_service.dart';
import '../services/ledger_pdf_service.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';

class CustomerLedgerDetailScreen extends ConsumerWidget {
  const CustomerLedgerDetailScreen({super.key, required this.customer});

  final CustomerLedger customer;

  Future<void> _exportXlsx(BuildContext context, WidgetRef ref) async {
    final entries =
        ref.read(customerLedgerDetailProvider(customer.customerId));
    if (entries.isEmpty) return;
    final service = LedgerExcelService();
    await service.saveCustomerDetail(customer, entries);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('XLSX exported successfully')),
      );
    }
  }

  Future<void> _exportPdf(BuildContext context, WidgetRef ref) async {
    final entries =
        ref.read(customerLedgerDetailProvider(customer.customerId));
    if (entries.isEmpty) return;
    final service = LedgerPdfService();
    await service.saveCustomerDetail(customer, entries);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF exported successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries =
        ref.watch(customerLedgerDetailProvider(customer.customerId));
    final totalDebit =
        entries.fold<double>(0, (s, e) => s + e.debit);
    final totalCredit =
        entries.fold<double>(0, (s, e) => s + e.credit);
    final lastBalance =
        entries.isEmpty ? 0.0 : entries.last.balance;

    return Scaffold(
      appBar: AppBar(
        title: Text(customer.name),
        actions: [
          const NotificationBell(),
          const SizedBox(width: 6),
          const ShopAvatar(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: _MiniCard(
                  label: 'Opening',
                  value: money(0),
                  valueColor: const Color(0xFF101828),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniCard(
                  label: 'Debit',
                  value: money(totalDebit),
                  valueColor: const Color(0xFFF97316),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MiniCard(
                  label: 'Credit',
                  value: money(totalCredit),
                  valueColor: const Color(0xFF059669),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniCard(
                  label: 'Balance',
                  value: money(lastBalance),
                  valueColor: const Color(0xFF059669),
                  borderColor: const Color(0xFF059669),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _FullExportButton(
                  label: 'Download XLSX',
                  icon: Icons.table_chart_outlined,
                  color: const Color(0xFF059669),
                  onTap: () => _exportXlsx(context, ref),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FullExportButton(
                  label: 'Download PDF',
                  icon: Icons.picture_as_pdf_rounded,
                  color: const Color(0xFFF97316),
                  onTap: () => _exportPdf(context, ref),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Debit / Credit Ledger',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF101828),
            ),
          ),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 32),
              child: Center(
                child: Text(
                  'No ledger entries found for this customer.',
                  style: TextStyle(
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE8DDD2)),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _headerRow(),
                    ...entries.map((e) => _entryRow(e)).toList(),
                    _totalRow(totalDebit, totalCredit, lastBalance),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _headerRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF9F5EF),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE8DDD2)),
        ),
      ),
      child: const Row(
        children: [
          SizedBox(width: 80, child: Text('DATE', style: _headerText)),
          SizedBox(
            width: 140,
            child: Text('PARTICULARS', style: _headerText),
          ),
          SizedBox(width: 80, child: Text('DEBIT', style: _headerText)),
          SizedBox(width: 80, child: Text('CREDIT', style: _headerText)),
          SizedBox(width: 80, child: Text('BALANCE', style: _headerText)),
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
            width: 140,
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

  Widget _totalRow(double debit, double credit, double balance) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF9F5EF),
        border: Border(
          top: BorderSide(color: Color(0xFFE8DDD2)),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 80, child: SizedBox.shrink()),
          const SizedBox(
            width: 140,
            child: Text(
              'TOTAL',
              style: TextStyle(
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
  color: Color(0xFF667085),
);

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.label,
    required this.value,
    required this.valueColor,
    this.borderColor,
  });

  final String label;
  final String value;
  final Color valueColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor ?? const Color(0xFFE8DDD2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF98A2B3),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
        ],
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
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
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
        ),
      ),
    );
  }
}
