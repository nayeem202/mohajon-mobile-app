import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_error.dart';

import '../../../core/models/customer.dart';
import '../../../core/models/ledger_entry.dart';
import '../../../core/models/sale.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/snackbar.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/widgets/async_action_state.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/insight_widgets.dart';
import '../../payments/presentation/add_payment_screen.dart';
import 'customer_form_screen.dart';
import '../providers/customer_providers.dart';
import '../../pos/services/whatsapp_service.dart';
import '../../settings/providers/shop_profile_providers.dart';
import '../../subscription/services/paywall_gate.dart';
import '../services/customer_ledger_excel_service.dart';
import '../services/due_recovery_service.dart';

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
    final l10n = AppLocalizations.of(context);
    final customer = widget.customer;
    final due = ref.watch(customerDueProvider(customer.customerId));
    final tag = ref.watch(customerTagProvider(customer.customerId));
    final ledger = ref.watch(customerLedgerProvider(customer.customerId));
    final sales = (ref.watch(salesStreamProvider).value ?? []).where(
      (s) => s.customerId == customer.customerId,
    );
    final totalSpent = sales.fold<double>(0, (s, sale) => s + sale.totalAmount);
    final debitTotal = ledger
        .where((entry) => entry.signedAmount > 0)
        .fold<double>(0, (sum, entry) => sum + entry.amount);
    final creditTotal = ledger
        .where((entry) => entry.signedAmount < 0)
        .fold<double>(0, (sum, entry) => sum + entry.amount);
    var running = 0.0;

    return withLoadingOverlay(
      Theme(
        data: MohajonWarm.theme(Theme.of(context)),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(customer.name),
            actions: [
              if (due > 0)
                IconButton(
                  tooltip: l10n.t('dueRecovery'),
                  onPressed: () => _showDueRecovery(
                    customer: customer,
                    due: due,
                    sales: sales.toList(),
                  ),
                  icon: const Icon(Icons.track_changes_rounded),
                ),
              IconButton(
                tooltip: l10n.t('edit'),
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
                : () => PaywallGate.guard(
                    context,
                    ref,
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AddPaymentScreen(customer: customer),
                      ),
                    ),
                  ),
            icon: const Icon(Icons.payments_outlined),
            label: Text(l10n.t('addPayment')),
          ),
          body: DecoratedBox(
            decoration: const BoxDecoration(gradient: MohajonWarm.pageGradient),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                Container(
                  decoration: InsightTokens.cardDecoration(
                    radius: 20,
                    accent: due > 0 ? MohajonWarm.orange : MohajonWarm.green,
                  ),
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
                                child: AppImage.file(
                                  File(customer.imagePath!),
                                  width: 42,
                                  height: 42,
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, stk) =>
                                      _iconAvatar(context),
                                ),
                              )
                            else
                              _iconAvatar(context),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          customer.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w900,
                                              ),
                                        ),
                                      ),
                                      if (tag.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: tag == 'VIP'
                                                ? const Color(0xFFFFF7ED)
                                                : const Color(0xFFF0FDF4),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            tag,
                                            style: TextStyle(
                                              color: tag == 'VIP'
                                                  ? const Color(0xFFE98300)
                                                  : const Color(0xFF047857),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
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
                                  l10n.t('totalDue'),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            const gap = 8.0;
                            final columns = constraints.maxWidth < 390 ? 2 : 3;
                            final width =
                                (constraints.maxWidth - gap * (columns - 1)) /
                                columns;
                            return Wrap(
                              spacing: gap,
                              runSpacing: gap,
                              children: [
                                SizedBox(
                                  width: width,
                                  child: _MiniStat(
                                    label: l10n.t('totalSpent'),
                                    value: money(totalSpent),
                                    icon: Icons.payments_rounded,
                                    color: MohajonWarm.green,
                                  ),
                                ),
                                SizedBox(
                                  width: width,
                                  child: _MiniStat(
                                    label: l10n.t('debit'),
                                    value: money(debitTotal),
                                    icon: Icons.call_made_rounded,
                                    color: MohajonWarm.red,
                                  ),
                                ),
                                SizedBox(
                                  width: width,
                                  child: _MiniStat(
                                    label: l10n.t('credit'),
                                    value: money(creditTotal),
                                    icon: Icons.call_received_rounded,
                                    color: MohajonWarm.green,
                                  ),
                                ),
                              ],
                            );
                          },
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
                                        title: l10n.t('addDebit'),
                                        icon: Icons.call_made_rounded,
                                        color: MohajonWarm.red,
                                        onSave: (amount, note) => ref
                                            .read(customerLedgerServiceProvider)
                                            .addDebit(
                                              customerId: customer.customerId,
                                              amount: amount,
                                              note: note,
                                            ),
                                      ),
                                icon: const Icon(Icons.add_circle_outline),
                                label: Text(l10n.t('debit')),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: isBusy
                                    ? null
                                    : () => _showLedgerEntrySheet(
                                        context,
                                        title: l10n.t('addCredit'),
                                        icon: Icons.call_received_rounded,
                                        color: MohajonWarm.green,
                                        onSave: (amount, note) => ref
                                            .read(customerLedgerServiceProvider)
                                            .addCredit(
                                              customerId: customer.customerId,
                                              amount: amount,
                                              note: note,
                                            ),
                                      ),
                                icon: const Icon(Icons.remove_circle_outline),
                                label: Text(l10n.t('credit')),
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
                        l10n.t('ledger'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: isBusy
                          ? null
                          : () => _exportLedger(customer, ledger),
                      icon: const Icon(Icons.download_rounded),
                      label: Text(l10n.t('exportLedger')),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (ledger.isEmpty)
                  InsightEmptyCard(
                    message: l10n.t('ledgerEmptyTitle'),
                    caption: l10n.t('ledgerEmptyHint'),
                    icon: Icons.receipt_long_outlined,
                    accent: MohajonWarm.muted,
                  ),
                for (final entry in ledger)
                  Builder(
                    builder: (context) {
                      running += entry.signedAmount;
                      final isPositive = entry.signedAmount > 0;
                      final color = switch (entry.type) {
                        LedgerEntryType.sale => Theme.of(
                          context,
                        ).colorScheme.error,
                        LedgerEntryType.debit => Theme.of(
                          context,
                        ).colorScheme.error,
                        LedgerEntryType.payment => Theme.of(
                          context,
                        ).colorScheme.primary,
                        LedgerEntryType.credit => Theme.of(
                          context,
                        ).colorScheme.primary,
                      };
                      final icon = switch (entry.type) {
                        LedgerEntryType.sale => Icons.point_of_sale_rounded,
                        LedgerEntryType.debit => Icons.arrow_upward_rounded,
                        LedgerEntryType.payment => Icons.payments_rounded,
                        LedgerEntryType.credit => Icons.arrow_downward_rounded,
                      };
                      final prefix = isPositive ? '+' : '-';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: InsightTokens.cardDecoration(
                          radius: 18,
                          accent: color,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 3,
                          ),
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(13),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.16),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(icon, color: color),
                          ),
                          title: Text(entry.description),
                          subtitle: Text(
                            entry.createdAt
                                .toLocal()
                                .toString()
                                .split('.')
                                .first,
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
                                '${l10n.t('balance')} ${money(running)}',
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
        ),
      ),
      label: 'Saving entry...',
    );
  }

  Future<void> _showDueRecovery({
    required Customer customer,
    required double due,
    required List<dynamic> sales,
  }) async {
    final service = ref.read(dueRecoveryServiceProvider);
    final l10n = AppLocalizations.of(context);
    await service.refreshFromServer(customer.customerId);
    if (!mounted) return;
    final payments = (ref.read(paymentsStreamProvider).value ?? const [])
        .where((payment) => payment.customerId == customer.customerId)
        .toList();
    final typedSales = sales.whereType<dynamic>().toList();
    var plan = service.getPlan(customer.customerId);
    var risk = service.risk(
      customer: customer,
      due: due,
      sales: typedSales.whereType<Sale>().toList(),
      payments: payments,
    );
    final shopName = ref.read(shopProfileProvider).value?.shopName ?? '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> refresh() async {
              plan = service.getPlan(customer.customerId);
              risk = service.risk(
                customer: customer,
                due: due,
                sales: typedSales.whereType<Sale>().toList(),
                payments: payments,
              );
              setState(() {});
            }

            Future<void> choosePromiseDate() async {
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                initialDate: plan.promisedPaymentDate ?? DateTime.now(),
              );
              if (picked == null) return;
              await service.setPromiseDate(
                customer.customerId,
                DateUtils.dateOnly(picked),
              );
              await refresh();
            }

            Future<void> send(DueFollowUpChannel channel) async {
              final message = WhatsAppService.dueReminderMessage(
                customerName: customer.name,
                dueAmount: due,
                shopName: shopName,
                t: (key) => l10n.t(key),
              );
              bool ok;
              if (channel == DueFollowUpChannel.whatsapp) {
                ok = await WhatsAppService.openChat(
                  phone: customer.phone,
                  message: message,
                );
              } else if (channel == DueFollowUpChannel.sms) {
                ok = await DueRecoveryService.openSms(
                  phone: customer.phone,
                  message: message,
                );
              } else {
                ok = await DueRecoveryService.openCall(customer.phone);
              }
              await service.addFollowUp(
                customerId: customer.customerId,
                channel: channel,
                status: ok ? 'opened' : 'failed',
                note: channel == DueFollowUpChannel.call
                    ? (ok ? 'Call opened' : 'Could not open call')
                    : (ok ? 'Reminder opened' : 'Could not open messaging app'),
              );
              await refresh();
            }

            final riskColor = risk.score >= 70
                ? Colors.red
                : risk.score >= 40
                ? Colors.orange
                : Colors.green;
            final riskLabel = risk.score >= 70
                ? l10n.t('dueRiskHigh')
                : risk.score >= 40
                ? l10n.t('dueRiskWatch')
                : l10n.t('dueRiskLow');
            return Theme(
              data: MohajonWarm.theme(Theme.of(context)),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: MohajonWarm.pageGradient,
                ),
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      18,
                      8,
                      18,
                      MediaQuery.viewInsetsOf(context).bottom + 20,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.t('dueRecoveryTitle'),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.tP('dueRecoveryCustomerDue', {
                              'name': customer.name,
                              'amount': money(due),
                            }),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  riskColor.withValues(alpha: 0.14),
                                  Colors.white.withValues(alpha: 0.72),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: riskColor.withValues(alpha: 0.24),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: riskColor.withValues(alpha: 0.10),
                                  blurRadius: 16,
                                  offset: const Offset(0, 7),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: riskColor.withValues(
                                  alpha: 0.16,
                                ),
                                child: Text(
                                  '${risk.score}',
                                  style: TextStyle(
                                    color: riskColor,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              title: Text(riskLabel),
                              subtitle: Text(l10n.t('dueRiskExplanation')),
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: choosePromiseDate,
                            icon: const Icon(Icons.event_available_rounded),
                            label: Text(
                              plan.promisedPaymentDate == null
                                  ? l10n.t('setPromiseDate')
                                  : l10n.tP('promisedDate', {
                                      'date': _shortDate(
                                        plan.promisedPaymentDate!,
                                      ),
                                    }),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final item in [
                                (const Duration(days: 1), 'snoozeOneDay'),
                                (const Duration(days: 3), 'snoozeThreeDays'),
                                (const Duration(days: 7), 'snoozeSevenDays'),
                              ])
                                ActionChip(
                                  avatar: const Icon(
                                    Icons.notifications_off_outlined,
                                    size: 16,
                                  ),
                                  label: Text(l10n.t(item.$2)),
                                  onPressed: () async {
                                    await service.snooze(
                                      customer.customerId,
                                      item.$1,
                                    );
                                    await refresh();
                                  },
                                ),
                            ],
                          ),
                          if (plan.isSnoozed) ...[
                            const SizedBox(height: 6),
                            TextButton.icon(
                              onPressed: () async {
                                await service.clearSnooze(customer.customerId);
                                await refresh();
                              },
                              icon: const Icon(
                                Icons.notifications_active_outlined,
                              ),
                              label: Text(
                                '${l10n.tP('snoozedUntil', {'date': _shortDate(plan.snoozedUntil!)})} • ${l10n.t('clearSnooze')}',
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Text(
                            l10n.t('contactCustomer'),
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () =>
                                      send(DueFollowUpChannel.whatsapp),
                                  icon: const Icon(Icons.chat_rounded),
                                  label: const Text('WhatsApp'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => send(DueFollowUpChannel.sms),
                                  icon: const Icon(Icons.sms_outlined),
                                  label: const Text('SMS'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                onPressed: () => send(DueFollowUpChannel.call),
                                icon: const Icon(Icons.call_outlined),
                                tooltip: l10n.t('voiceCall'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.t('followUpHistory'),
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 6),
                          if (plan.followUps.isEmpty)
                            Text(l10n.t('noFollowUps'))
                          else
                            for (final item in plan.followUps.take(8))
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(switch (item.channel) {
                                  DueFollowUpChannel.whatsapp =>
                                    Icons.chat_rounded,
                                  DueFollowUpChannel.sms => Icons.sms_outlined,
                                  DueFollowUpChannel.call =>
                                    Icons.call_outlined,
                                }),
                                title: Row(
                                  children: [
                                    Text(
                                      item.channel ==
                                              DueFollowUpChannel.whatsapp
                                          ? 'WhatsApp'
                                          : item.channel ==
                                                DueFollowUpChannel.sms
                                          ? 'SMS'
                                          : l10n.t('voiceCall'),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      switch (item.status) {
                                        'queued' => l10n.t('reminderQueued'),
                                        'sent' => l10n.t('reminderSent'),
                                        'delivered' => l10n.t(
                                          'reminderDelivered',
                                        ),
                                        'opened' => l10n.t('reminderOpened'),
                                        'failed' => l10n.t('reminderFailed'),
                                        _ => item.status,
                                      },
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: item.status == 'failed'
                                            ? Colors.red
                                            : item.status == 'delivered'
                                            ? Colors.green
                                            : Colors.blueGrey,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  '${_shortDateTime(item.createdAt)}${item.note.isEmpty ? '' : ' • ${item.note}'}',
                                ),
                                trailing: PopupMenuButton<String>(
                                  tooltip: l10n.t('updateReminderStatus'),
                                  onSelected: (status) async {
                                    try {
                                      await service.updateFollowUpStatus(
                                        customerId: customer.customerId,
                                        followUpId: item.id,
                                        status: status,
                                      );
                                      await refresh();
                                    } catch (_) {
                                      if (context.mounted) {
                                        showAppSnackBar(
                                          context,
                                          l10n.t('reminderStatusUpdateFailed'),
                                          isError: true,
                                        );
                                      }
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    PopupMenuItem(
                                      value: 'delivered',
                                      child: Text(
                                        l10n.t('markReminderDelivered'),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'failed',
                                      child: Text(l10n.t('markReminderFailed')),
                                    ),
                                  ],
                                ),
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
      },
    );
  }

  String _shortDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  String _shortDateTime(DateTime date) =>
      '${_shortDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  Future<void> _exportLedger(
    Customer customer,
    List<LedgerEntry> ledger,
  ) async {
    try {
      await runBusyAction(() async {
        final file = await _ledgerExcelService.saveToDownloads(
          customer,
          ledger,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ledger exported to ${file.path}')),
        );
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyErrorMessage(error, l10n: AppLocalizations.of(context)),
          ),
        ),
      );
    }
  }

  Future<void> _showLedgerEntrySheet(
    BuildContext context, {
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
                                await onSave(
                                  amount,
                                  noteController.text.trim(),
                                );
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MohajonWarm.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MohajonWarm.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _iconAvatar(BuildContext context) {
  return Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(
      Icons.account_balance_wallet_rounded,
      color: Theme.of(context).colorScheme.primary,
    ),
  );
}
