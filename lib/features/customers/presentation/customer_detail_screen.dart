import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/customer.dart';
import '../../../core/models/ledger_entry.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/async_action_state.dart';
import '../../payments/presentation/add_payment_screen.dart';
import 'customer_form_screen.dart';
import '../providers/customer_providers.dart';
import '../services/customer_ledger_excel_service.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  const CustomerDetailScreen({super.key, required this.customer});

  final Customer customer;

  @override
  ConsumerState<CustomerDetailScreen> createState() =>
      _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen>
    with AsyncActionState<CustomerDetailScreen> {
  final _ledgerExcelService = CustomerLedgerExcelService();

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final customer = widget.customer;
    final due = ref.watch(customerDueProvider(customer.customerId));
    final ledger = ref.watch(customerLedgerProvider(customer.customerId));
    final debitTotal = ledger
        .where((entry) => entry.signedAmount > 0)
        .fold<double>(0, (sum, entry) => sum + entry.amount);
    final creditTotal = ledger
        .where((entry) => entry.signedAmount < 0)
        .fold<double>(0, (sum, entry) => sum + entry.amount);
    var running = 0.0;

    return withLoadingOverlay(
      Scaffold(
        appBar: AppBar(
          title: Text(customer.name),
          actions: [
            IconButton(
              tooltip: 'Edit customer',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CustomerFormScreen(customer: customer),
                ),
              ),
              icon: const Icon(Icons.edit_rounded),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: isBusy
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AddPaymentScreen(customer: customer),
                  ),
                ),
          icon: const Icon(Icons.payments_outlined),
          label: const Text('Add payment'),
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
                      if (customer.imagePath != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(customer.imagePath!),
                            width: 42,
                            height: 42,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stk) => _iconAvatar(context),
                          ),
                        )
                      else
                        _iconAvatar(context),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 3),
                            Text(customer.phone),
                            if (customer.email.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                customer.email,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            money(due),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            'Due balance',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _MiniStat(
                        label: 'Debit',
                        value: money(debitTotal),
                        icon: Icons.call_made_rounded,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 10),
                      _MiniStat(
                        label: 'Credit',
                        value: money(creditTotal),
                        icon: Icons.call_received_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: isBusy
                              ? null
                              : () => _showLedgerEntrySheet(
                            context,
                            title: 'Add debit',
                            icon: Icons.call_made_rounded,
                            color: Theme.of(context).colorScheme.error,
                            onSave: (amount, note) => ref
                                .read(customerLedgerServiceProvider)
                                .addDebit(
                                  customerId: customer.customerId,
                                  amount: amount,
                                  note: note,
                                ),
                          ),
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Debit'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isBusy
                              ? null
                              : () => _showLedgerEntrySheet(
                            context,
                            title: 'Add credit',
                            icon: Icons.call_received_rounded,
                            color: Theme.of(context).colorScheme.primary,
                            onSave: (amount, note) => ref
                                .read(customerLedgerServiceProvider)
                                .addCredit(
                                  customerId: customer.customerId,
                                  amount: amount,
                                  note: note,
                                ),
                          ),
                          icon: const Icon(Icons.remove_circle_outline),
                          label: const Text('Credit'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ledger',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              TextButton.icon(
                onPressed: isBusy
                    ? null
                    : () => _exportLedger(customer, ledger),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Export Ledger'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (ledger.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.receipt_long_outlined),
                title: Text('No ledger activity yet'),
                subtitle: Text('Add a debit or credit to track the customer balance.'),
              ),
            ),
          for (final entry in ledger)
            Builder(
              builder: (context) {
                running += entry.signedAmount;
                final isPositive = entry.signedAmount > 0;
                final color = switch (entry.type) {
                  LedgerEntryType.sale => Theme.of(context).colorScheme.error,
                  LedgerEntryType.debit => Theme.of(context).colorScheme.error,
                  LedgerEntryType.payment => Theme.of(context).colorScheme.primary,
                  LedgerEntryType.credit => Theme.of(context).colorScheme.primary,
                };
                final icon = switch (entry.type) {
                  LedgerEntryType.sale => Icons.point_of_sale_rounded,
                  LedgerEntryType.debit => Icons.arrow_upward_rounded,
                  LedgerEntryType.payment => Icons.payments_rounded,
                  LedgerEntryType.credit => Icons.arrow_downward_rounded,
                };
                final prefix = isPositive ? '+' : '-';

                return Card(
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color),
                    ),
                    title: Text(entry.description),
                    subtitle: Text(
                      entry.createdAt.toLocal().toString().split('.').first,
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$prefix${money(entry.amount)}',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Bal ${money(running)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
        ),
      ),
      label: 'Saving entry...',
    );
  }

  Future<void> _exportLedger(Customer customer, List<LedgerEntry> ledger) async {
    try {
      await runBusyAction(() async {
        final file = await _ledgerExcelService.saveToDownloads(customer, ledger);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ledger exported to ${file.path}'),
          ),
        );
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _showLedgerEntrySheet(
    BuildContext context,
    {
    required String title,
    required IconData icon,
    required Color color,
    required Future<void> Function(double amount, String note) onSave,
  }) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        var saving = false;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, color: color),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Amount'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    enabled: !saving,
                    decoration: const InputDecoration(labelText: 'Note'),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: saving
                          ? null
                          : () async {
                              final amount =
                                  double.tryParse(amountController.text) ?? 0;
                              if (amount <= 0) return;
                              setSheetState(() => saving = true);
                              try {
                                await onSave(amount, noteController.text.trim());
                                if (sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop();
                                }
                              } finally {
                                if (sheetContext.mounted) {
                                  setSheetState(() => saving = false);
                                }
                              }
                            },
                      child: saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save entry'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    amountController.dispose();
    noteController.dispose();
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
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
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
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

Widget _iconAvatar(BuildContext context) {
  return Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: Theme.of(context)
          .colorScheme
          .primary
          .withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(
      Icons.account_balance_wallet_rounded,
      color: Theme.of(context).colorScheme.primary,
    ),
  );
}
