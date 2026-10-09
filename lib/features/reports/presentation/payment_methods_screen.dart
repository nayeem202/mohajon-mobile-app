import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/sale.dart';
import '../../../core/services/pdf_doc.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';
import '../../customers/providers/customer_providers.dart';
import '../../payments/providers/payment_providers.dart';
import '../../settings/providers/shop_profile_providers.dart';
import '../../pos/services/sale_return_service.dart';
import '../models/table_report.dart';
import '../services/payment_methods_excel_service.dart';
import '../services/payment_methods_pdf_service.dart';
import 'report_shared_widgets.dart';

class PaymentMethodsScreen extends ConsumerStatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  ConsumerState<PaymentMethodsScreen> createState() =>
      _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends ConsumerState<PaymentMethodsScreen>
    with ReportExportMixin {
  late DateTimeRange _range;

  @override
  void initState() {
    super.initState();
    _range = reportMonthRange(DateTime.now());
  }

  Future<void> _pickRange() async {
    final l10n = AppLocalizations.of(context);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
      initialDateRange: _range,
      helpText: l10n.t('selectPaymentsRange'),
      saveText: l10n.t('applyLabel'),
    );
    if (picked == null) return;
    setState(() => _range = picked);
  }

  bool _inRange(DateTime value) {
    final end = _range.end;
    return !value.isBefore(_range.start) &&
        !value.isAfter(DateTime(end.year, end.month, end.day, 23, 59, 59));
  }

  ({
    List<Map<String, Object?>> rows,
    int paymentCount,
    double received,
    ReportTableData table,
  })
  _compute() {
    final payments = ref.watch(paymentsProvider).value ?? const <Payment>[];
    final sales = ref.watch(salesStreamProvider).value ?? const <Sale>[];
    final returns = ref.watch(saleReturnsProvider).value ?? const [];

    final byMethod = <String, Map<String, Object?>>{};
    for (final payment in payments) {
      if (!_inRange(payment.createdAt)) continue;
      final key = payment.paymentMethod.name;
      final entry = byMethod.putIfAbsent(key, () {
        return <String, Object?>{'count': 0, 'amount': 0.0};
      });
      entry['count'] = (entry['count'] as int) + 1;
      entry['amount'] = (entry['amount'] as double) + payment.amount;
    }

    var walkInCount = 0;
    var walkInAmount = 0.0;
    for (final sale in sales) {
      if (!_inRange(sale.createdAt)) continue;
      final hasCustomer =
          sale.customerId.isNotEmpty &&
          sale.customerId.toLowerCase() != 'walk_in';
      if (!hasCustomer && sale.paidAmount > 0) {
        walkInCount++;
        walkInAmount += sale.paidAmount;
      }
    }
    for (final value in returns) {
      if (!_inRange(value.createdAt) || value.isDeleted) continue;
      final key = value.refundMethod.toLowerCase();
      final entry = byMethod.putIfAbsent(key, () {
        return <String, Object?>{'count': 0, 'amount': 0.0};
      });
      entry['amount'] = (entry['amount'] as double) - value.refundAmount;
    }
    if (walkInCount > 0) {
      byMethod['cash_walk_in'] = {
        'count': walkInCount,
        'amount': walkInAmount,
        'walkIn': true,
      };
    }

    final rows =
        byMethod.entries
            .map(
              (entry) => <String, Object?>{
                'method': entry.key,
                'count': entry.value['count'],
                'amount': entry.value['amount'],
                'walkIn': entry.value['walkIn'] ?? false,
              },
            )
            .toList()
          ..sort(
            (a, b) => (b['amount'] as double).compareTo(a['amount'] as double),
          );

    final paymentCount = rows.fold<int>(
      0,
      (sum, row) => sum + (row['count'] as int),
    );
    final received = rows.fold<double>(
      0,
      (sum, row) => sum + (row['amount'] as double),
    );

    final table = ReportTableData(
      title: 'Payment Methods',
      subtitle: reportRangeLabel(_range),
      summaries: [
        ReportSummary(
          label: 'Payments',
          value: '$paymentCount',
          accent: 0xFF1E3A8A,
        ),
        ReportSummary(
          label: 'Received',
          value: money(received),
          accent: 0xFF059669,
        ),
        ReportSummary(
          label: 'Methods Used',
          value: '${rows.length}',
          accent: 0xFFEA580C,
        ),
        ReportSummary(
          label: 'Top Method',
          value: rows.isEmpty ? '—' : _methodLabel('${rows.first['method']}'),
          accent: 0xFFD97706,
        ),
      ],
      columns: const [
        ReportTableColumn(key: 'method', header: 'Method', weight: 2.5),
        ReportTableColumn(key: 'count', header: 'Payments', rightAlign: true),
        ReportTableColumn(key: 'amount', header: 'Amount', rightAlign: true),
      ],
      rows: [
        ...rows,
        {'method': 'TOTAL', 'count': paymentCount, 'amount': received},
      ],
    );

    return (
      rows: rows,
      paymentCount: paymentCount,
      received: received,
      table: table,
    );
  }

  Future<void> _exportXlsx() => runExport(
    isXlsx: true,
    task: () async {
      final data = _compute();
      await PaymentMethodsExcelService().savePaymentMethods(
        table: data.table,
        range: _range,
      );
    },
    message: AppLocalizations.of(context).tP('exportedAsXlsx', {
      'report': AppLocalizations.of(context).t('reportPaymentMethods'),
    }),
  );

  Future<void> _exportPdf() => runExport(
    isXlsx: false,
    task: () async {
      final data = _compute();
      final company = await DocCompany.fromShopForExport(
        ref.read(shopProfileProvider).value,
      );
      await PaymentMethodsPdfService().savePaymentMethods(
        table: data.table,
        range: _range,
        company: company,
      );
    },
    message: AppLocalizations.of(context).tP('exportedAsPdf', {
      'report': AppLocalizations.of(context).t('reportPaymentMethods'),
    }),
  );

  IconData _methodIcon(String key) {
    switch (key) {
      case 'cash':
        return Icons.payments_outlined;
      case 'cash_walk_in':
        return Icons.storefront_outlined;
      case 'bkash':
      case 'nagad':
        return Icons.smartphone_outlined;
      case 'credit':
        return Icons.credit_card_outlined;
      case 'bank':
        return Icons.account_balance_outlined;
      default:
        return Icons.more_horiz;
    }
  }

  Color _methodColor(String key) {
    switch (key) {
      case 'cash':
        return const Color(0xFF059669);
      case 'cash_walk_in':
        return const Color(0xFF9A3412);
      case 'bkash':
      case 'nagad':
        return const Color(0xFFD97706);
      case 'credit':
        return const Color(0xFF0F766E);
      case 'bank':
        return const Color(0xFFB45309);
      default:
        return const Color(0xFF667085);
    }
  }

  String _methodLabel(String key) {
    if (key == 'cash_walk_in') {
      return AppLocalizations.of(context).t('cashWalkIn');
    }
    return PaymentMethodX.parse(key).displayName;
  }

  @override
  Widget build(BuildContext context) {
    final data = _compute();
    final l10n = AppLocalizations.of(context);

    return Theme(
      data: MohajonWarm.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            l10n.t('reportPaymentMethods'),
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
          actions: const [NotificationBell(), SizedBox(width: 6), ShopAvatar()],
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: MohajonWarm.pageGradient),
          child: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                ReportBrandStrip(
                  title: l10n.t('reportPaymentMethods'),
                  icon: Icons.payments_rounded,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ReportSummaryCard(
                        label: l10n.t('paymentsLabel'),
                        value: '${data.paymentCount}',
                        valueColor: MohajonWarm.goldText,
                        icon: Icons.payments_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ReportSummaryCard(
                        label: l10n.t('receivedLabel'),
                        value: money(data.received),
                        valueColor: const Color(0xFF059669),
                        icon: Icons.call_received_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ReportSummaryCard(
                        label: l10n.t('methodsUsed'),
                        value: '${data.rows.length}',
                        valueColor: const Color(0xFFF97316),
                        icon: Icons.bolt_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ReportSummaryCard(
                        label: l10n.t('topMethod'),
                        value: data.rows.isEmpty
                            ? '—'
                            : _methodLabel('${data.rows.first['method']}'),
                        valueColor: const Color(0xFF9A3412),
                        icon: Icons.emoji_events_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ReportRangeSelector(
                  range: _range,
                  onPickRange: _pickRange,
                  onThisMonth: () =>
                      setState(() => _range = reportMonthRange(DateTime.now())),
                  onLastMonth: () => setState(
                    () => _range = reportPreviousMonthRange(DateTime.now()),
                  ),
                  onLast30Days: () => setState(
                    () => _range = reportLast30DaysRange(DateTime.now()),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ReportExportButton(
                        label: l10n.t('downloadXlsx'),
                        icon: Icons.table_chart_outlined,
                        color: const Color(0xFF059669),
                        isBusy: exportingXlsx,
                        onTap: _exportXlsx,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ReportExportButton(
                        label: l10n.t('downloadPdf'),
                        icon: Icons.picture_as_pdf_rounded,
                        color: const Color(0xFFF97316),
                        isBusy: exportingPdf,
                        onTap: _exportPdf,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.t('collectionsByMethod'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF101828),
                        ),
                      ),
                    ),
                    Text(
                      l10n.tP('totalWithCount', {
                        'amount': money(data.received),
                      }),
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final row in data.rows) ...[
                  ReportRowTile(
                    icon: _methodIcon('${row['method']}'),
                    iconColor: _methodColor('${row['method']}'),
                    title: _methodLabel('${row['method']}'),
                    subtitle: l10n.tP('xPayments', {
                      'count': '${row['count']}',
                    }),
                    trailing: money(row['amount'] as double),
                  ),
                  const SizedBox(height: 8),
                ],
                if (data.rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        l10n.t('noPaymentsInPeriod'),
                        style: const TextStyle(
                          color: Color(0xFF98A2B3),
                          fontWeight: FontWeight.w600,
                        ),
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
}
