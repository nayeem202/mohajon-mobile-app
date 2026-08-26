import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_error.dart';

import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/async_action_state.dart';
import '../models/vendor.dart';
import '../providers/vendor_providers.dart';
import 'vendor_form_screen.dart';

class VendorDetailScreen extends ConsumerStatefulWidget {
  const VendorDetailScreen({super.key, required this.vendor});
  final Vendor vendor;

  @override
  ConsumerState<VendorDetailScreen> createState() =>
      _VendorDetailScreenState();
}

class _VendorDetailScreenState extends ConsumerState<VendorDetailScreen>
    with AsyncActionState<VendorDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final vendor = widget.vendor;
    final outstanding = ref.watch(vendorOutstandingProvider(vendor.vendorId));
    final purchases = ref.watch(
      vendorPurchasesForVendorProvider(vendor.vendorId),
    );
    final payments = ref.watch(
      vendorPaymentsForVendorProvider(vendor.vendorId),
    );
    final ledger = ref.watch(vendorLedgerProvider(vendor.vendorId));
    final totalPaid = payments.fold<double>(0, (s, p) => s + p.amount);
    final totalPurchased =
        purchases.fold<double>(0, (s, p) => s + p.amount);

    return withLoadingOverlay(
      Theme(
        data: MohajonWarm.theme(Theme.of(context)),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: MohajonWarm.pageGradient,
            ),
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                children: [
                  _DetailHeader(
                    title: vendor.companyName,
                    subtitle: 'Vendor profile',
                    onBack: () => Navigator.of(context).maybePop(),
                    onEdit: () => _openEditVendor(vendor),
                    onDelete: () => _confirmDelete(vendor),
                  ),
                  const SizedBox(height: 16),
                  _VendorHeroCard(
                    vendor: vendor,
                    orders: purchases.length,
                    totalSpent: totalPurchased,
                    outstanding: outstanding,
                  ),
                  const SizedBox(height: 14),
                  _PanelSection(
                    icon: Icons.store_rounded,
                    iconColor: MohajonWarm.goldText,
                    iconBackground: MohajonWarm.tintYellow,
                    title: 'Company Information',
                    children: [
                      _DetailRow(label: 'Phone', value: vendor.phone),
                      _DetailRow(
                        label: 'Email',
                        value: vendor.email.isEmpty
                            ? 'Not provided'
                            : vendor.email,
                      ),
                      _DetailRow(
                        label: 'Category',
                        value: vendor.category.isEmpty
                            ? 'General'
                            : vendor.category,
                      ),
                      _DetailRow(
                        label: 'Address',
                        value: vendor.address.isEmpty
                            ? 'Not provided'
                            : vendor.address,
                      ),
                      _DetailRow(
                        label: 'Products',
                        value: vendor.products.isEmpty
                            ? 'Not specified'
                            : vendor.products,
                        showDivider: false,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _PanelSection(
                    icon: Icons.receipt_long_rounded,
                    iconColor: MohajonWarm.orange,
                    iconBackground: MohajonWarm.tintOrange,
                    title: 'Vendor Ledger',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PillButton(
                          icon: Icons.shopping_cart_rounded,
                          label: 'Purchase',
                          onTap: () => _showRecordPurchaseSheet(vendor),
                        ),
                        const SizedBox(width: 8),
                        _PillButton(
                          icon: Icons.payments_rounded,
                          label: 'Payment',
                          onTap: () => _showRecordPaymentSheet(vendor),
                        ),
                      ],
                    ),
                    children: _buildLedger(ledger),
                  ),
                  const SizedBox(height: 14),
                  _PanelSection(
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: outstanding > 0
                        ? MohajonWarm.red
                        : MohajonWarm.green,
                    iconBackground: outstanding > 0
                        ? MohajonWarm.tintRed
                        : MohajonWarm.tintGreen,
                    title: 'Outstanding Balance',
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _BalanceTile(
                              label: 'Total Purchases',
                              value: money(totalPurchased),
                              color: MohajonWarm.red,
                              background: MohajonWarm.tintRed,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _BalanceTile(
                              label: 'Total Paid',
                              value: money(totalPaid),
                              color: MohajonWarm.green,
                              background: MohajonWarm.tintGreen,
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
                              ? MohajonWarm.tintRed
                              : MohajonWarm.tintGreen,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: (outstanding > 0
                                    ? MohajonWarm.red
                                    : MohajonWarm.green)
                                .withValues(alpha: 0.25),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              outstanding > 0
                                  ? 'Remaining Balance'
                                  : 'All Cleared',
                              style: TextStyle(
                                color: outstanding > 0
                                    ? MohajonWarm.red
                                    : MohajonWarm.green,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              money(outstanding),
                              style: TextStyle(
                                color: outstanding > 0
                                    ? MohajonWarm.red
                                    : MohajonWarm.green,
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
                    const SizedBox(height: 14),
                    _PanelSection(
                      icon: Icons.inventory_2_outlined,
                      iconColor: MohajonWarm.goldText,
                      iconBackground: MohajonWarm.tintYellow,
                      title: 'Products Supplied',
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: vendor.products.split(',').map((p) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: MohajonWarm.goldBorder,
                                ),
                              ),
                              child: Text(
                                p.trim(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: MohajonWarm.muted,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  _PanelSection(
                    icon: Icons.notes_outlined,
                    iconColor: MohajonWarm.green,
                    iconBackground: MohajonWarm.tintGreen,
                    title: 'Notes',
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: MohajonWarm.tintYellow,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: MohajonWarm.goldBorder),
                        ),
                        child: Text(
                          vendor.products.isNotEmpty
                              ? 'Supplies: ${vendor.products}'
                              : 'No notes added.',
                          style: const TextStyle(
                            color: Color(0xFF5D4A00),
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      label: 'Processing...',
    );
  }

  List<Widget> _buildLedger(List<VendorLedgerEntry> ledger) {
    if (ledger.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'No transactions recorded yet.',
            style: TextStyle(
              color: MohajonWarm.muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ];
    }
    var runningBalance = 0.0;
    return ledger.map((entry) {
      runningBalance +=
          entry.type == 'purchase' ? entry.amount : -entry.amount;
      return _LedgerRow(
        type: entry.type,
        amount: entry.amount,
        description: entry.description,
        reference: entry.reference,
        itemsSupplied: entry.itemsSupplied,
        date: entry.date,
        balance: runningBalance,
      );
    }).toList();
  }

  void _openEditVendor(Vendor vendor) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VendorFormScreen(vendor: vendor)),
    );
  }

  Future<void> _confirmDelete(Vendor vendor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        var deleting = false;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => PopScope(
            canPop: !deleting,
            child: Material(
              color: Colors.transparent,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFEBEE),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.error_outline_rounded,
                          color: Color(0xFFEF5350),
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Delete Vendor?',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1C1917),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '${vendor.companyName} will be removed permanently. '
                          'This action cannot be undone.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF98A2B3),
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 40,
                              child: OutlinedButton(
                                onPressed: deleting
                                    ? null
                                    : () => Navigator.of(ctx).pop(false),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF0ECE6),
                                  foregroundColor: const Color(0xFF525252),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide.none,
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 40,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFEF5350),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                onPressed: deleting
                                    ? null
                                    : () async {
                                        setDialogState(
                                          () => deleting = true,
                                        );
                                        try {
                                          await runBusyAction(
                                            () => ref
                                                .read(vendorServiceProvider)
                                                .delete(vendor.vendorId),
                                          );
                                          if (ctx.mounted) {
                                            Navigator.of(ctx).pop(true);
                                          }
                                        } catch (error) {
                                          if (ctx.mounted) {
                                            ScaffoldMessenger.of(ctx)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  friendlyErrorMessage(
                                                    error,
                                                    fallback:
                                                        'Could not delete vendor.',
                                                  ),
                                                ),
                                              ),
                                            );
                                          }
                                        } finally {
                                          if (ctx.mounted) {
                                            setDialogState(
                                              () => deleting = false,
                                            );
                                          }
                                        }
                                      },
                                child: deleting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Delete'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _showRecordPurchaseSheet(Vendor vendor) async {
    final warmTheme = MohajonWarm.theme(Theme.of(context));
    final amountCtrl = TextEditingController();
    final itemsCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MohajonWarm.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Theme(
          data: warmTheme,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
            ),
            child: StatefulBuilder(
              builder: (ctx, setSheetState) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: MohajonWarm.goldBorder,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: MohajonWarm.tintRed,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.shopping_cart_rounded,
                              color: MohajonWarm.red,
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Record Purchase',
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w900,
                                    color: MohajonWarm.ink,
                                  ),
                                ),
                                Text(
                                  vendor.companyName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: MohajonWarm.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: amountCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.]'),
                          ),
                        ],
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
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          onPressed: saving
                              ? null
                              : () async {
                                  final amount = double.tryParse(
                                    amountCtrl.text,
                                  );
                                  if (amount == null || amount <= 0) {
                                    return;
                                  }
                                  setSheetState(() => saving = true);
                                  try {
                                    await ref
                                        .read(vendorServiceProvider)
                                        .recordPurchase(
                                      vendorId: vendor.vendorId,
                                      amount: amount,
                                      notes: noteCtrl.text.trim(),
                                      itemsSupplied:
                                          itemsCtrl.text.trim(),
                                    );
                                    if (sheetContext.mounted) {
                                      Navigator.of(sheetContext).pop();
                                    }
                                  } catch (error) {
                                    if (sheetContext.mounted) {
                                      ScaffoldMessenger.of(sheetContext)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            friendlyErrorMessage(error),
                                          ),
                                        ),
                                      );
                                    }
                                  } finally {
                                    saving = false;
                                    if (sheetContext.mounted) {
                                      setSheetState(() {});
                                    }
                                  }
                                },
                          child: saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Save Purchase'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _showRecordPaymentSheet(Vendor vendor) async {
    final warmTheme = MohajonWarm.theme(Theme.of(context));
    final amountCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String method = 'cash';
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MohajonWarm.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Theme(
          data: warmTheme,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
            ),
            child: StatefulBuilder(
              builder: (ctx, setSheetState) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: MohajonWarm.goldBorder,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: MohajonWarm.tintGreen,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.payments_outlined,
                              color: MohajonWarm.green,
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Record Payment',
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w900,
                                    color: MohajonWarm.ink,
                                  ),
                                ),
                                Text(
                                  vendor.companyName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: MohajonWarm.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: amountCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.]'),
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Amount *',
                          prefixText: '৳ ',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: method,
                        style: const TextStyle(
                          color: MohajonWarm.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        dropdownColor: Colors.white,
                        decoration: const InputDecoration(
                          labelText: 'Payment Method',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'cash',
                            child: Text('Cash'),
                          ),
                          DropdownMenuItem(
                            value: 'bkash',
                            child: Text('bKash'),
                          ),
                          DropdownMenuItem(
                            value: 'nagad',
                            child: Text('Nagad'),
                          ),
                          DropdownMenuItem(
                            value: 'bank',
                            child: Text('Bank'),
                          ),
                          DropdownMenuItem(
                            value: 'check',
                            child: Text('Check'),
                          ),
                          DropdownMenuItem(
                            value: 'other',
                            child: Text('Other'),
                          ),
                        ],
                        onChanged: (v) =>
                            setSheetState(() => method = v ?? 'cash'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: refCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Reference',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          onPressed: saving
                              ? null
                              : () async {
                                  final amount = double.tryParse(
                                    amountCtrl.text,
                                  );
                                  if (amount == null || amount <= 0) {
                                    return;
                                  }
                                  setSheetState(() => saving = true);
                                  try {
                                    await ref
                                        .read(vendorServiceProvider)
                                        .recordPayment(
                                      vendorId: vendor.vendorId,
                                      amount: amount,
                                      method: method,
                                      reference: refCtrl.text.trim(),
                                      notes: noteCtrl.text.trim(),
                                    );
                                    if (sheetContext.mounted) {
                                      Navigator.of(sheetContext).pop();
                                    }
                                  } catch (error) {
                                    if (sheetContext.mounted) {
                                      ScaffoldMessenger.of(sheetContext)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            friendlyErrorMessage(error),
                                          ),
                                        ),
                                      );
                                    }
                                  } finally {
                                    saving = false;
                                    if (sheetContext.mounted) {
                                      setSheetState(() {});
                                    }
                                  }
                                },
                          child: saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Save Payment'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.onEdit,
    required this.onDelete,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            borderRadius: BorderRadius.circular(11),
            onTap: onBack,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: MohajonWarm.goldBorder),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: MohajonWarm.ink,
                size: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [MohajonWarm.primary, MohajonWarm.primaryPale],
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: MohajonWarm.primary.withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.store_rounded,
            color: MohajonWarm.ink,
            size: 17,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: MohajonWarm.ink,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: MohajonWarm.muted,
                ),
              ),
            ],
          ),
        ),
        _HeaderAction(icon: Icons.edit_rounded, onTap: onEdit),
        const SizedBox(width: 8),
        _HeaderAction(
          icon: Icons.delete_outline_rounded,
          iconColor: MohajonWarm.red,
          onTap: onDelete,
        ),
      ],
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: MohajonWarm.goldBorder),
          ),
          child: Icon(
            icon,
            color: iconColor ?? MohajonWarm.ink,
            size: 17,
          ),
        ),
      ),
    );
  }
}

class _VendorHeroCard extends StatelessWidget {
  const _VendorHeroCard({
    required this.vendor,
    required this.orders,
    required this.totalSpent,
    required this.outstanding,
  });

  final Vendor vendor;
  final int orders;
  final double totalSpent;
  final double outstanding;

  @override
  Widget build(BuildContext context) {
    final isDue = outstanding > 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MohajonWarm.tintYellow, MohajonWarm.card],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MohajonWarm.goldBorder),
        boxShadow: [
          BoxShadow(
            color: MohajonWarm.primary.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFE9CF), Color(0xFFFCD9AE)],
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(15)),
                ),
                child: Center(
                  child: Text(
                    _initials(vendor.companyName),
                    style: const TextStyle(
                      color: Color(0xFFE98300),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MohajonWarm.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      vendor.contactPerson,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MohajonWarm.muted,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  label: 'Orders',
                  value: '$orders',
                  icon: Icons.receipt_long_rounded,
                  color: MohajonWarm.goldText,
                  background: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniMetric(
                  label: 'Total Spent',
                  value: money(totalSpent),
                  icon: Icons.payments_rounded,
                  color: MohajonWarm.green,
                  background: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniMetric(
                  label: 'Balance',
                  value: money(outstanding),
                  icon: Icons.account_balance_wallet_rounded,
                  color: isDue ? MohajonWarm.red : MohajonWarm.green,
                  background: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.background,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MohajonWarm.goldBorder),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.14),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MohajonWarm.primary.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: MohajonWarm.primary.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, size: 14, color: MohajonWarm.ink),
              const SizedBox(width: 3),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF5D4A00),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelSection extends StatelessWidget {
  const _PanelSection({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.children,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MohajonWarm.card,
        border: Border.all(color: MohajonWarm.goldBorder),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: MohajonWarm.ink.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MohajonWarm.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const Spacer(),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
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
                  style: const TextStyle(
                    color: MohajonWarm.muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: MohajonWarm.ink,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, color: Color(0xFFF3ECDA)),
      ],
    );
  }
}

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  final String label;
  final String value;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: color,
              fontWeight: FontWeight.w700,
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

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({
    required this.type,
    required this.amount,
    required this.description,
    this.reference,
    this.itemsSupplied,
    required this.date,
    required this.balance,
  });

  final String type;
  final double amount;
  final String description;
  final String? reference;
  final String? itemsSupplied;
  final DateTime date;
  final double balance;

  @override
  Widget build(BuildContext context) {
    final isPurchase = type == 'purchase';
    final color = isPurchase ? MohajonWarm.red : MohajonWarm.green;
    final background = isPurchase
        ? MohajonWarm.tintRed
        : MohajonWarm.tintGreen;
    final icon = isPurchase
        ? Icons.shopping_cart_rounded
        : Icons.payments_rounded;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 15),
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
                    color: MohajonWarm.ink,
                  ),
                ),
                if (itemsSupplied != null && itemsSupplied!.isNotEmpty)
                  Text(
                    itemsSupplied!,
                    style: const TextStyle(
                      fontSize: 10,
                      color: MohajonWarm.muted,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else if (reference != null && reference!.isNotEmpty)
                  Text(
                    reference!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: MohajonWarm.muted,
                      fontWeight: FontWeight.w600,
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
                    color: MohajonWarm.muted,
                    fontWeight: FontWeight.w600,
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
                color: balance > 0 ? MohajonWarm.red : MohajonWarm.green,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty);
  if (parts.isEmpty) return 'VN';
  final value = parts.take(2).map((p) => p[0].toUpperCase()).join();
  return value.length == 1 ? '${value}N' : value;
}
