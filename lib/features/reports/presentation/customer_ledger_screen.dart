import 'package:flutter/material.dart';

import '../../../core/utils/money.dart';
import '../data/sample_data.dart';
import '../models/customer_ledger.dart';
import 'customer_ledger_detail_screen.dart';

class CustomerLedgerScreen extends StatefulWidget {
  const CustomerLedgerScreen({super.key});

  @override
  State<CustomerLedgerScreen> createState() => _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends State<CustomerLedgerScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = customerLedgersWithMax();
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Ledger'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {},
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFD6F2EA),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'KA',
              style: TextStyle(
                color: Color(0xFF0F766E),
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
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
                onTap: () => debugPrint('Export Customer Ledger XLSX'),
              ),
              const SizedBox(width: 6),
              _ExportPill(
                label: 'PDF',
                color: const Color(0xFFF97316),
                onTap: () => debugPrint('Export Customer Ledger PDF'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'July 1 – July 10, 2026 · ${customers.length} of ${all.length} customers',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF98A2B3),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8DDD2)),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8DDD2)),
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
                    backgroundColor: const Color(0xFFF6E7D1),
                    child: Text(
                      customer.name[0].toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Color(0xFFE98300),
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
                            valueColor: const AlwaysStoppedAnimation<Color>(
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
                            valueColor: const AlwaysStoppedAnimation<Color>(
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
