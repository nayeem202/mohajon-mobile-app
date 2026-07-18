import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../core/widgets/async_action_state.dart';
import '../models/vendor.dart';
import '../providers/vendor_providers.dart';
import 'vendor_form_sheet.dart';

class VendorDetailScreen extends ConsumerStatefulWidget {
  const VendorDetailScreen({super.key, required this.vendor});
  final Vendor vendor;

  @override
  ConsumerState<VendorDetailScreen> createState() => _VendorDetailScreenState();
}

class _VendorDetailScreenState extends ConsumerState<VendorDetailScreen>
    with AsyncActionState<VendorDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final vendor = widget.vendor;
    final outstanding = ref.watch(vendorOutstandingProvider(vendor.vendorId));
    final purchases = ref.watch(vendorPurchasesForVendorProvider(vendor.vendorId));
    final payments = ref.watch(vendorPaymentsForVendorProvider(vendor.vendorId));
    final ledger = ref.watch(vendorLedgerProvider(vendor.vendorId));
    final totalPaid = payments.fold<double>(0, (s, p) => s + p.amount);
    final totalPurchased = purchases.fold<double>(0, (s, p) => s + p.amount);
    final colors = Theme.of(context).colorScheme;

    return withLoadingOverlay(
      Scaffold(
        appBar: AppBar(
          title: Text(vendor.companyName),
          actions: [
            IconButton(
              tooltip: 'Edit vendor',
              onPressed: () => _openEditVendor(vendor),
              icon: const Icon(Icons.edit_rounded),
            ),
            IconButton(
              tooltip: 'Delete vendor',
              onPressed: () => _confirmDelete(vendor),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              _initials(vendor.companyName),
                              style: TextStyle(
                                color: colors.primary,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                vendor.companyName,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                vendor.contactPerson,
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _MiniMetric(
                          label: 'Total Orders',
                          value: '${purchases.length}',
                          icon: Icons.receipt_long_rounded,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 10),
                        _MiniMetric(
                          label: 'Total Spent',
                          value: money(totalPurchased),
                          icon: Icons.payments_rounded,
                          color: colors.secondary,
                        ),
                        const SizedBox(width: 10),
                        _MiniMetric(
                          label: 'Balance',
                          value: money(outstanding),
                          icon: Icons.account_balance_wallet_rounded,
                          color: outstanding > 0 ? colors.error : const Color(0xFF047857),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Company Information',
              children: [
                _DetailRow(label: 'Phone', value: vendor.phone),
                _DetailRow(label: 'Email', value: vendor.email.isEmpty ? 'Not provided' : vendor.email),
                _DetailRow(label: 'Category', value: vendor.category.isEmpty ? 'General' : vendor.category),
                _DetailRow(label: 'Address', value: vendor.address.isEmpty ? 'Not provided' : vendor.address),
                _DetailRow(label: 'Products', value: vendor.products.isEmpty ? 'Not specified' : vendor.products, showDivider: false),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Vendor Ledger',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: () => _showRecordPurchaseSheet(vendor),
                    icon: const Icon(Icons.shopping_cart_rounded, size: 16),
                    label: const Text('Purchase'),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: () => _showRecordPaymentSheet(vendor),
                    icon: const Icon(Icons.payments_rounded, size: 16),
                    label: const Text('Payment'),
                  ),
                ],
              ),
              children: _buildLedger(ledger, colors),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Outstanding Balance',
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _BalanceTile(
                        label: 'Total Purchases',
                        value: money(totalPurchased),
                        color: colors.error,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _BalanceTile(
                        label: 'Total Paid',
                        value: money(totalPaid),
                        color: colors.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: outstanding > 0
                        ? colors.error.withValues(alpha: 0.08)
                        : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        outstanding > 0 ? 'Remaining Balance' : 'All Cleared',
                        style: TextStyle(
                          color: outstanding > 0 ? colors.error : const Color(0xFF047857),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        money(outstanding),
                        style: TextStyle(
                          color: outstanding > 0 ? colors.error : const Color(0xFF047857),
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (vendor.products.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Products Supplied',
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: vendor.products
                        .split(',')
                        .map((p) => Chip(
                              label: Text(p.trim(), style: const TextStyle(fontSize: 12)),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ))
                        .toList(),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notes',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F6F1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        vendor.products.isNotEmpty
                            ? 'Supplies: ${vendor.products}'
                            : 'No notes added.',
                        style: const TextStyle(
                          color: Color(0xFF475467),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      label: 'Processing...',
    );
  }

  void _openEditVendor(Vendor vendor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VendorFormSheet(vendor: vendor),
    );
  }

  Future<void> _confirmDelete(Vendor vendor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Vendor'),
        content: Text('Delete ${vendor.companyName}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () async {
              await ref.read(vendorServiceProvider).delete(vendor.vendorId);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (ctx.mounted) Navigator.of(ctx).pop(true);
              });
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  List<Widget> _buildLedger(List<VendorLedgerEntry> ledger, ColorScheme colors) {
    if (ledger.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('No transactions recorded yet.'),
        ),
      ];
    }
    var runningBalance = 0.0;
    return ledger.map((entry) {
      runningBalance += entry.type == 'purchase' ? entry.amount : -entry.amount;
      return _LedgerRow(
        type: entry.type,
        amount: entry.amount,
        description: entry.description,
        reference: entry.reference,
        itemsSupplied: entry.itemsSupplied,
        date: entry.date,
        balance: runningBalance,
        purchaseColor: colors.error,
        paymentColor: colors.primary,
      );
    }).toList();
  }

  Future<void> _showRecordPurchaseSheet(Vendor vendor) async {
    final itemsCtrl = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final amountCtrl = TextEditingController();
        final noteCtrl = TextEditingController();
        var saving = false;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.shopping_cart_rounded, color: Color(0xFFDC2626)),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Record Purchase',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Amount *',
                        prefixText: '৳ ',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: itemsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Items Supplied',
                        hintText: 'e.g. Rice 50kg, Oil 10L',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(labelText: 'Notes'),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: saving ? null : () async {
                          final amount = double.tryParse(amountCtrl.text) ?? 0;
                          if (amount <= 0) return;
                          setSheetState(() => saving = true);
                          try {
                            await ref.read(vendorServiceProvider).recordPurchase(
                              vendorId: vendor.vendorId,
                              amount: amount,
                              notes: noteCtrl.text.trim(),
                              itemsSupplied: itemsCtrl.text.trim(),
                            );
                            if (sheetContext.mounted) {
                              Navigator.of(sheetContext).pop();
                            }
                          } finally {
                            if (sheetContext.mounted) setSheetState(() => saving = false);
                          }
                        },
                        child: saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Save Purchase'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showRecordPaymentSheet(Vendor vendor) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final amountCtrl = TextEditingController();
        final refCtrl = TextEditingController();
        final noteCtrl = TextEditingController();
        String method = 'cash';
        var saving = false;
        return StatefulBuilder(
            builder: (ctx, setSheetState) {
              return Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.payments_outlined, color: Color(0xFF0F766E)),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Record Payment',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Amount *',
                          prefixText: '৳ ',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: method,
                        decoration: const InputDecoration(labelText: 'Payment Method'),
                        items: const [
                          DropdownMenuItem(value: 'cash', child: Text('Cash')),
                          DropdownMenuItem(value: 'bkash', child: Text('bKash')),
                          DropdownMenuItem(value: 'nagad', child: Text('Nagad')),
                          DropdownMenuItem(value: 'bank', child: Text('Bank')),
                          DropdownMenuItem(value: 'check', child: Text('Check')),
                          DropdownMenuItem(value: 'other', child: Text('Other')),
                        ],
                        onChanged: (v) => setSheetState(() => method = v ?? 'cash'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: refCtrl,
                        decoration: const InputDecoration(labelText: 'Reference'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteCtrl,
                        decoration: const InputDecoration(labelText: 'Notes'),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: saving ? null : () async {
                            final amount = double.tryParse(amountCtrl.text) ?? 0;
                            if (amount <= 0) return;
                            setSheetState(() => saving = true);
                            try {
                              await ref.read(vendorServiceProvider).recordPayment(
                                vendorId: vendor.vendorId,
                                amount: amount,
                                method: method,
                                reference: refCtrl.text.trim(),
                                notes: noteCtrl.text.trim(),
                              );
                              if (sheetContext.mounted) {
                                Navigator.of(sheetContext).pop();
                              }
                            } finally {
                              if (sheetContext.mounted) setSheetState(() => saving = false);
                            }
                          },
                          child: saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Save Payment'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
      },
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
    this.trailing,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF101828),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1, color: Color(0xFFF0ECE4)),
      ],
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({
    required this.type,
    required this.amount,
    required this.description,
    this.reference,
    this.itemsSupplied,
    required this.date,
    required this.balance,
    required this.purchaseColor,
    required this.paymentColor,
  });

  final String type;
  final double amount;
  final String description;
  final String? reference;
  final String? itemsSupplied;
  final DateTime date;
  final double balance;
  final Color purchaseColor;
  final Color paymentColor;

  @override
  Widget build(BuildContext context) {
    final isPurchase = type == 'purchase';
    final color = isPurchase ? purchaseColor : paymentColor;
    final icon = isPurchase ? Icons.shopping_cart_rounded : Icons.payments_rounded;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Color(0xFF101828),
                  ),
                ),
                if (itemsSupplied != null)
                  Text(
                    itemsSupplied!,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF667085),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (reference != null && itemsSupplied == null)
                  Text(
                    reference!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF667085),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  money(amount),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: color,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${date.day}/${date.month}/${date.year}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF98A2B3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              money(balance),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: balance > 0 ? purchaseColor : const Color(0xFF047857),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return 'VN';
  final value = parts.take(2).map((p) => p[0].toUpperCase()).join();
  return value.length == 1 ? '${value}N' : value;
}
