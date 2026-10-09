import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/product.dart';
import '../../../core/models/purchase.dart';
import '../../../core/models/sale.dart';
import '../../../core/services/download_export_service.dart';
import '../../../core/services/pdf_doc.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/money.dart';
import '../../customers/providers/customer_providers.dart';
import '../../expenses/providers/expense_providers.dart';
import '../../products/providers/product_providers.dart';
import '../../purchases/providers/purchase_providers.dart';
import '../../settings/providers/shop_profile_providers.dart';
import '../../pos/services/sale_return_service.dart';
import '../../vendors/models/vendor.dart';
import '../../vendors/models/vendor_payment.dart';
import '../../vendors/models/vendor_purchase.dart';
import '../../vendors/providers/vendor_providers.dart';
import '../models/table_report.dart';
import '../services/report_table_pdf.dart';
import '../services/report_table_xlsx.dart';
import 'report_shared_widgets.dart';

enum OperationalReportType {
  cashClosing,
  purchaseSupplier,
  stockMovement,
  customerCredit,
  salesProfit,
  staffPerformance,
  auditActivity,
}

class OperationalReportScreen extends ConsumerStatefulWidget {
  const OperationalReportScreen({super.key, required this.type});

  final OperationalReportType type;

  @override
  ConsumerState<OperationalReportScreen> createState() =>
      _OperationalReportScreenState();
}

class _OperationalReportScreenState
    extends ConsumerState<OperationalReportScreen>
    with ReportExportMixin {
  late DateTimeRange _range;
  bool _xlsxBusy = false;
  bool _pdfBusy = false;

  @override
  void initState() {
    super.initState();
    _range = reportMonthRange(DateTime.now());
  }

  String _title(AppLocalizations l10n) => switch (widget.type) {
    OperationalReportType.cashClosing => l10n.t('reportCashClosing'),
    OperationalReportType.purchaseSupplier => l10n.t('reportPurchaseSupplier'),
    OperationalReportType.stockMovement => l10n.t('reportStockMovement'),
    OperationalReportType.customerCredit => l10n.t('reportCustomerCredit'),
    OperationalReportType.salesProfit => l10n.t('reportSalesProfit'),
    OperationalReportType.staffPerformance => l10n.t('reportStaffPerformance'),
    OperationalReportType.auditActivity => l10n.t('reportAuditActivity'),
  };

  _OperationalData _compute() {
    final sales = ref.watch(salesStreamProvider).value ?? const <Sale>[];
    final payments =
        ref.watch(paymentsStreamProvider).value ?? const <Payment>[];
    final expenses = ref.watch(expensesProvider).value ?? const [];
    final products = ref.watch(productsProvider).value ?? const <Product>[];
    final purchases = ref.watch(purchasesProvider).value ?? const <Purchase>[];
    final vendors = ref.watch(vendorsProvider).value ?? const <Vendor>[];
    final vendorPurchases =
        ref.watch(vendorPurchasesProvider).value ?? const <VendorPurchase>[];
    final vendorPayments =
        ref.watch(vendorPaymentsProvider).value ?? const <VendorPayment>[];
    final saleReturns = ref.watch(saleReturnsProvider).value ?? const [];
    final productById = {for (final p in products) p.productId: p};
    final vendorById = {for (final v in vendors) v.vendorId: v};
    bool inRange(DateTime d) =>
        !d.isBefore(_range.start) &&
        !d.isAfter(
          DateTime(
            _range.end.year,
            _range.end.month,
            _range.end.day,
            23,
            59,
            59,
          ),
        );

    final rows = <Map<String, Object?>>[];
    late List<ReportTableColumn> columns;
    final summaries = <ReportSummary>[];

    switch (widget.type) {
      case OperationalReportType.cashClosing:
        final periodSales = sales.where((s) => inRange(s.createdAt)).toList();
        final periodPayments = payments
            .where((p) => inRange(p.createdAt))
            .toList();
        final periodExpenses = expenses.where((e) => inRange(e.date)).toList();
        final periodReturns = saleReturns
            .where((r) => inRange(r.createdAt) && !r.isDeleted)
            .toList();
        final periodSaleById = {
          for (final sale in periodSales) sale.saleId: sale,
        };
        final cashPaidBySale = <String, double>{};
        var manualCashCollections = 0.0;
        for (final payment in periodPayments) {
          if (payment.paymentMethod != PaymentMethod.cash) continue;
          final sale = payment.saleId == null
              ? null
              : periodSaleById[payment.saleId!];
          if (sale != null && sale.paymentMethod == PaymentMethod.cash) {
            cashPaidBySale[payment.saleId!] =
                (cashPaidBySale[payment.saleId!] ?? 0) + payment.amount;
          } else {
            manualCashCollections += payment.amount;
          }
        }
        final cashSalesPaid = periodSales
            .where((sale) => sale.paymentMethod == PaymentMethod.cash)
            .fold<double>(0, (sum, sale) {
              final recorded = cashPaidBySale[sale.saleId];
              return sum + (recorded ?? sale.paidAmount);
            });
        final received = manualCashCollections;
        final spent = periodExpenses.fold<double>(0, (s, x) => s + x.amount);
        final refunded = periodReturns.fold<double>(
          0,
          (s, x) =>
              s + (x.refundMethod.toUpperCase() == 'CASH' ? x.refundAmount : 0),
        );
        final expected = cashSalesPaid + received - spent - refunded;
        summaries.addAll([
          ReportSummary(
            label: 'Sales paid',
            value: money(cashSalesPaid),
            accent: 0xFF059669,
          ),
          ReportSummary(
            label: 'Collections',
            value: money(received),
            accent: 0xFF2563EB,
          ),
          ReportSummary(
            label: 'Expenses',
            value: money(spent),
            accent: 0xFFDC2626,
          ),
          ReportSummary(
            label: 'Expected closing',
            value: money(expected),
            accent: 0xFFD97706,
          ),
        ]);
        columns = const [
          ReportTableColumn(key: 'date', header: 'Date'),
          ReportTableColumn(
            key: 'sales',
            header: 'Sales paid',
            rightAlign: true,
          ),
          ReportTableColumn(
            key: 'received',
            header: 'Received',
            rightAlign: true,
          ),
          ReportTableColumn(
            key: 'expenses',
            header: 'Expenses',
            rightAlign: true,
          ),
          ReportTableColumn(
            key: 'expected',
            header: 'Expected cash',
            rightAlign: true,
          ),
        ];
        for (
          var d = DateTime(
            _range.start.year,
            _range.start.month,
            _range.start.day,
          );
          !d.isAfter(_range.end);
          d = d.add(const Duration(days: 1))
        ) {
          final daySales = periodSales.where((s) => _sameDay(s.createdAt, d));
          final dayPayments = periodPayments.where(
            (p) => _sameDay(p.createdAt, d),
          );
          final dayExpenses = periodExpenses.where((e) => _sameDay(e.date, d));
          final daySaleById = {for (final sale in daySales) sale.saleId: sale};
          final dayCashPaidBySale = <String, double>{};
          var dayManualCashCollections = 0.0;
          for (final payment in dayPayments) {
            if (payment.paymentMethod != PaymentMethod.cash) continue;
            final sale = payment.saleId == null
                ? null
                : daySaleById[payment.saleId!];
            if (sale != null && sale.paymentMethod == PaymentMethod.cash) {
              dayCashPaidBySale[payment.saleId!] =
                  (dayCashPaidBySale[payment.saleId!] ?? 0) + payment.amount;
            } else {
              dayManualCashCollections += payment.amount;
            }
          }
          final a = daySales
              .where((sale) => sale.paymentMethod == PaymentMethod.cash)
              .fold<double>(0, (sum, sale) {
                final recorded = dayCashPaidBySale[sale.saleId];
                return sum + (recorded ?? sale.paidAmount);
              });
          final b = dayManualCashCollections;
          final c = dayExpenses.fold<double>(0, (s, x) => s + x.amount);
          final dayRefunds = saleReturns
              .where((r) => !r.isDeleted && _sameDay(r.createdAt, d))
              .fold<double>(
                0,
                (s, x) => s +
                    (x.refundMethod.toUpperCase() == 'CASH'
                        ? x.refundAmount
                        : 0),
              );
          if (a == 0 && b == 0 && c == 0 && dayRefunds == 0) continue;
          rows.add({
            'date': DateFormat('dd MMM yyyy').format(d),
            'sales': a,
            'received': b,
            'expenses': c + dayRefunds,
            'expected': a + b - c - dayRefunds,
          });
        }
        break;
      case OperationalReportType.purchaseSupplier:
        final grouped = <String, Map<String, Object?>>{};
        for (final p in purchases.where((p) => inRange(p.createdAt))) {
          final x = grouped.putIfAbsent(
            p.supplierId,
            () => {'purchase': 0.0, 'paid': 0.0, 'orders': 0},
          );
          x['purchase'] = (x['purchase'] as double) + p.totalAmount;
          x['paid'] = (x['paid'] as double) + p.paidAmount;
          x['orders'] = (x['orders'] as int) + 1;
        }
        for (final p in vendorPurchases.where((p) => inRange(p.date))) {
          final x = grouped.putIfAbsent(
            p.vendorId,
            () => {'purchase': 0.0, 'paid': 0.0, 'orders': 0},
          );
          x['purchase'] = (x['purchase'] as double) + p.amount;
          x['orders'] = (x['orders'] as int) + 1;
        }
        for (final p in vendorPayments.where((p) => inRange(p.date))) {
          final x = grouped.putIfAbsent(
            p.vendorId,
            () => {'purchase': 0.0, 'paid': 0.0, 'orders': 0},
          );
          x['paid'] = (x['paid'] as double) + p.amount;
        }
        columns = const [
          ReportTableColumn(key: 'supplier', header: 'Supplier', weight: 2),
          ReportTableColumn(key: 'orders', header: 'Orders', rightAlign: true),
          ReportTableColumn(
            key: 'purchase',
            header: 'Purchase',
            rightAlign: true,
          ),
          ReportTableColumn(key: 'paid', header: 'Paid', rightAlign: true),
          ReportTableColumn(key: 'due', header: 'Due', rightAlign: true),
        ];
        for (final entry in grouped.entries) {
          final x = entry.value;
          final purchase = x['purchase'] as double;
          final paid = x['paid'] as double;
          rows.add({
            'supplier': vendorById[entry.key]?.companyName ?? entry.key,
            'orders': x['orders'],
            'purchase': purchase,
            'paid': paid,
            'due': purchase - paid,
          });
        }
        rows.sort(
          (a, b) =>
              (b['purchase'] as double).compareTo(a['purchase'] as double),
        );
        final total = rows.fold<double>(
          0,
          (s, r) => s + (r['purchase'] as double),
        );
        summaries.add(
          ReportSummary(
            label: 'Total purchase',
            value: money(total),
            accent: 0xFF7C3AED,
          ),
        );
        summaries.add(
          ReportSummary(
            label: 'Suppliers',
            value: '${rows.length}',
            accent: 0xFF2563EB,
          ),
        );
        break;
      case OperationalReportType.stockMovement:
        final sold = <String, double>{};
        final bought = <String, double>{};
        for (final s in sales.where((s) => inRange(s.createdAt))) {
          for (final i in s.items) {
            sold[i.productId] = (sold[i.productId] ?? 0) + i.qty;
          }
        }
        for (final p in purchases.where((p) => inRange(p.createdAt))) {
          for (final i in p.items) {
            bought[i.productId] = (bought[i.productId] ?? 0) + i.qty;
          }
        }
        columns = const [
          ReportTableColumn(key: 'product', header: 'Product', weight: 2),
          ReportTableColumn(key: 'opening', header: 'In', rightAlign: true),
          ReportTableColumn(key: 'sold', header: 'Sold', rightAlign: true),
          ReportTableColumn(key: 'closing', header: 'Stock', rightAlign: true),
          ReportTableColumn(
            key: 'value',
            header: 'Stock value',
            rightAlign: true,
          ),
        ];
        for (final p in products) {
          final soldQty = sold[p.productId] ?? 0;
          final boughtQty = bought[p.productId] ?? 0;
          if (soldQty == 0 && boughtQty == 0 && p.stockQty <= 0) continue;
          rows.add({
            'product': p.displayName('en'),
            'opening': boughtQty,
            'sold': soldQty,
            'closing': p.stockQty,
            'value': p.stockQty * p.purchasePrice,
          });
        }
        rows.sort(
          (a, b) => (b['value'] as double).compareTo(a['value'] as double),
        );
        final dead = rows
            .where(
              (r) => (r['closing'] as int) > 0 && (r['sold'] as double) == 0,
            )
            .length;
        summaries.addAll([
          ReportSummary(
            label: 'Products',
            value: '${rows.length}',
            accent: 0xFF2563EB,
          ),
          ReportSummary(
            label: 'Dead stock',
            value: '$dead',
            accent: 0xFFDC2626,
          ),
          ReportSummary(
            label: 'Stock value',
            value: money(
              rows.fold<double>(0, (s, r) => s + (r['value'] as double)),
            ),
            accent: 0xFFD97706,
          ),
        ]);
        break;
      case OperationalReportType.customerCredit:
        final customerMap = {
          for (final c in (ref.watch(customersProvider).value ?? const []))
            c.customerId: c,
        };
        final due = <String, double>{};
        final lastSale = <String, DateTime>{};
        for (final s in sales) {
          due[s.customerId] = (due[s.customerId] ?? 0) + s.dueAmount;
          if (!lastSale.containsKey(s.customerId) ||
              s.createdAt.isAfter(lastSale[s.customerId]!)) {
            lastSale[s.customerId] = s.createdAt;
          }
        }
        for (final p in payments) {
          due[p.customerId] = (due[p.customerId] ?? 0) - p.amount;
        }
        columns = const [
          ReportTableColumn(key: 'customer', header: 'Customer', weight: 2),
          ReportTableColumn(key: 'due', header: 'Due', rightAlign: true),
          ReportTableColumn(
            key: 'age',
            header: 'Last activity',
            rightAlign: true,
          ),
          ReportTableColumn(key: 'risk', header: 'Risk', rightAlign: true),
        ];
        for (final e in due.entries.where((e) => e.value > 0.01)) {
          final last = lastSale[e.key];
          final age = last == null ? 0 : DateTime.now().difference(last).inDays;
          rows.add({
            'customer': customerMap[e.key]?.name ?? e.key,
            'due': e.value,
            'age': '${age}d',
            'risk': age > 30
                ? 'High'
                : age > 14
                ? 'Medium'
                : 'Low',
          });
        }
        rows.sort((a, b) => (b['due'] as double).compareTo(a['due'] as double));
        summaries.add(
          ReportSummary(
            label: 'Total due',
            value: money(
              rows.fold<double>(0, (s, r) => s + (r['due'] as double)),
            ),
            accent: 0xFFDC2626,
          ),
        );
        summaries.add(
          ReportSummary(
            label: 'Customers at risk',
            value: '${rows.where((r) => r['risk'] == 'High').length}',
            accent: 0xFFF97316,
          ),
        );
        break;
      case OperationalReportType.salesProfit:
        final grouped = <String, Map<String, double>>{};
        final returnedQty = <String, double>{};
        for (final value in saleReturns.where((item) => !item.isDeleted)) {
          for (final item in value.items) {
            returnedQty['${value.saleId}:${item.saleItemId}'] =
                (returnedQty['${value.saleId}:${item.saleItemId}'] ?? 0) +
                item.qty;
          }
        }
        for (final s in sales.where((s) => inRange(s.createdAt))) {
          for (final i in s.items) {
            final qty =
                (i.qty - (returnedQty['${s.saleId}:${i.saleItemId}'] ?? 0))
                    .clamp(0, double.infinity);
            final category = productById[i.productId]?.category.trim();
            final key = category?.isNotEmpty == true
                ? category!
                : 'Uncategorized';
            final x = grouped.putIfAbsent(key, () => {'sales': 0, 'profit': 0});
            x['sales'] = x['sales']! + qty * i.unitPrice;
            x['profit'] = x['profit']! + qty * (i.unitPrice - i.purchasePrice);
          }
        }
        columns = const [
          ReportTableColumn(key: 'category', header: 'Category', weight: 2),
          ReportTableColumn(key: 'sales', header: 'Sales', rightAlign: true),
          ReportTableColumn(key: 'profit', header: 'Profit', rightAlign: true),
          ReportTableColumn(key: 'margin', header: 'Margin', rightAlign: true),
        ];
        for (final e in grouped.entries) {
          final s = e.value['sales']!;
          final p = e.value['profit']!;
          rows.add({
            'category': e.key,
            'sales': s,
            'profit': p,
            'margin': s == 0 ? '0%' : '${(p / s * 100).toStringAsFixed(1)}%',
          });
        }
        rows.sort(
          (a, b) => (b['profit'] as double).compareTo(a['profit'] as double),
        );
        summaries.addAll([
          ReportSummary(
            label: 'Sales',
            value: money(
              rows.fold<double>(0, (s, r) => s + (r['sales'] as double)),
            ),
            accent: 0xFF2563EB,
          ),
          ReportSummary(
            label: 'Profit',
            value: money(
              rows.fold<double>(0, (s, r) => s + (r['profit'] as double)),
            ),
            accent: 0xFF059669,
          ),
        ]);
        break;
      case OperationalReportType.staffPerformance:
        final staff = {
          for (final user in ref.read(localDatabaseProvider).users.values())
            user.userId: user.name.isEmpty ? user.phone : user.name,
        };
        final grouped = <String, Map<String, double>>{};
        for (final sale in sales.where((sale) => inRange(sale.createdAt))) {
          final key = sale.staffId ?? 'unattributed';
          final entry = grouped.putIfAbsent(
            key,
            () => {'sales': 0, 'paid': 0, 'discount': 0, 'orders': 0},
          );
          entry['sales'] = entry['sales']! + sale.totalAmount;
          entry['discount'] = entry['discount']! + sale.discount;
          entry['orders'] = entry['orders']! + 1;
        }
        // Collection attribution must come from payment rows, not sale.paidAmount:
        // a later manual collection may be entered by a different staff member.
        for (final payment in payments.where(
          (payment) => !payment.isDeleted && inRange(payment.createdAt),
        )) {
          final key = payment.staffId ?? 'unattributed';
          final entry = grouped.putIfAbsent(
            key,
            () => {'sales': 0, 'paid': 0, 'discount': 0, 'orders': 0},
          );
          entry['paid'] = entry['paid']! + payment.amount;
        }
        columns = const [
          ReportTableColumn(key: 'staff', header: 'Staff', weight: 2),
          ReportTableColumn(key: 'orders', header: 'Orders', rightAlign: true),
          ReportTableColumn(key: 'sales', header: 'Sales', rightAlign: true),
          ReportTableColumn(key: 'paid', header: 'Collected', rightAlign: true),
          ReportTableColumn(
            key: 'discount',
            header: 'Discount',
            rightAlign: true,
          ),
        ];
        for (final entry in grouped.entries) {
          final values = entry.value;
          rows.add({
            'staff':
                staff[entry.key] ??
                (entry.key == 'unattributed' ? 'Unattributed' : entry.key),
            'orders': values['orders']!.toInt(),
            'sales': values['sales'],
            'paid': values['paid'],
            'discount': values['discount'],
          });
        }
        rows.sort(
          (a, b) => (b['sales'] as double).compareTo(a['sales'] as double),
        );
        summaries.add(
          ReportSummary(
            label: 'Staff with sales',
            value: '${rows.length}',
            accent: 0xFF2563EB,
          ),
        );
        summaries.add(
          ReportSummary(
            label: 'Unattributed',
            value:
                '${rows.where((row) => row['staff'] == 'Unattributed').length}',
            accent: 0xFFF97316,
          ),
        );
        break;
      case OperationalReportType.auditActivity:
        final db = ref.read(localDatabaseProvider);
        columns = const [
          ReportTableColumn(key: 'area', header: 'Area', weight: 2),
          ReportTableColumn(
            key: 'count',
            header: 'Pending / deleted',
            rightAlign: true,
          ),
        ];
        final values = <String, int>{
          'Sales': db.sales
              .values(includeDeleted: true)
              .where((x) => x.isDeleted || x.syncStatus.name == 'pending')
              .length,
          'Payments': db.payments
              .values(includeDeleted: true)
              .where((x) => x.isDeleted || x.syncStatus.name == 'pending')
              .length,
          'Customers': db.customers
              .values(includeDeleted: true)
              .where((x) => x.isDeleted || x.syncStatus.name == 'pending')
              .length,
          'Products': db.products
              .values(includeDeleted: true)
              .where((x) => x.isDeleted || x.syncStatus.name == 'pending')
              .length,
          'Purchases': db.purchases
              .values(includeDeleted: true)
              .where((x) => x.isDeleted || x.syncStatus.name == 'pending')
              .length,
          'Purchase orders': db.purchaseOrders
              .values(includeDeleted: true)
              .where((x) => x.isDeleted || x.syncStatus.name == 'pending')
              .length,
          'Expenses': db.expenses
              .values(includeDeleted: true)
              .where((x) => x.isDeleted || x.syncStatus.name == 'pending')
              .length,
        };
        rows.addAll(
          values.entries.map((e) => {'area': e.key, 'count': e.value}),
        );
        summaries.add(
          const ReportSummary(
            label: 'Audit status',
            value: 'Local trail',
            accent: 0xFF7C3AED,
          ),
        );
        break;
    }
    return _OperationalData(
      title: '',
      subtitle: reportRangeLabel(_range),
      columns: columns,
      rows: rows,
      summaries: summaries,
    );
  }

  Future<void> _export(bool pdf, _OperationalData data) async {
    if (pdf && _pdfBusy || !pdf && _xlsxBusy) return;
    setState(() {
      if (pdf) {
        _pdfBusy = true;
      } else {
        _xlsxBusy = true;
      }
    });
    try {
      final table = ReportTableData(
        title: data.title,
        subtitle: data.subtitle,
        columns: data.columns,
        rows: data.rows,
        summaries: data.summaries,
      );
      final Uint8List bytes;
      final String mime;
      final String extension;
      if (pdf) {
        bytes = await buildTablePdf(
          table,
          await DocCompany.fromShopForExport(
            ref.read(shopProfileProvider).value,
          ),
        );
        mime = 'application/pdf';
        extension = 'pdf';
      } else {
        bytes = buildTableXlsx(table);
        mime =
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        extension = 'xlsx';
      }
      await DownloadExportService().saveFileToDownloads(
        fileName: '${data.title.toLowerCase().replaceAll(' ', '-')}.$extension',
        mimeType: mime,
        bytes: bytes,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              ).tP('exportedAsX', {'format': extension.toUpperCase()}),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          if (pdf) {
            _pdfBusy = false;
          } else {
            _xlsxBusy = false;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final base = _compute();
    final data = _OperationalData(
      title: _title(l10n),
      subtitle: base.subtitle,
      columns: base.columns,
      rows: base.rows,
      summaries: base.summaries,
    );
    return Theme(
      data: MohajonWarm.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            data.title,
            style: const TextStyle(
              color: MohajonWarm.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          backgroundColor: MohajonWarm.primary,
          foregroundColor: MohajonWarm.ink,
          elevation: 0,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: MohajonWarm.primary,
            statusBarIconBrightness: Brightness.dark,
          ),
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: MohajonWarm.pageGradient),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              ReportBrandStrip(title: data.title, icon: Icons.analytics_rounded),
              const SizedBox(height: 14),
              ReportRangeSelector(
                range: _range,
                onPickRange: () async {
                  final r = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(DateTime.now().year + 1),
                    initialDateRange: _range,
                  );
                  if (r != null) setState(() => _range = r);
                },
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
              if (data.summaries.isNotEmpty)
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.45,
                  children: [
                    for (final s in data.summaries)
                      ReportSummaryCard(
                        label: s.label,
                        value: s.value,
                        valueColor: Color(s.accent),
                      ),
                  ],
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ReportExportButton(
                      label: l10n.t('downloadXlsx'),
                      icon: Icons.table_chart_outlined,
                      color: const Color(0xFF059669),
                      isBusy: _xlsxBusy,
                      onTap: () => _export(false, data),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ReportExportButton(
                      label: l10n.t('downloadPdf'),
                      icon: Icons.picture_as_pdf_rounded,
                      color: const Color(0xFFF97316),
                      isBusy: _pdfBusy,
                      onTap: () => _export(true, data),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (data.rows.isEmpty)
                Center(
                  child: Text(
                    l10n.t('noDataInPeriod'),
                    style: const TextStyle(color: MohajonWarm.muted),
                  ),
                )
              else
                _DataTableCard(data: data),
            ],
          ),
        ),
      ),
    );
  }
}

class _OperationalData {
  const _OperationalData({
    required this.title,
    required this.subtitle,
    required this.columns,
    required this.rows,
    required this.summaries,
  });
  final String title;
  final String subtitle;
  final List<ReportTableColumn> columns;
  final List<Map<String, Object?>> rows;
  final List<ReportSummary> summaries;
}

class _DataTableCard extends StatelessWidget {
  const _DataTableCard({required this.data});
  final _OperationalData data;
  @override
  Widget build(BuildContext context) => Container(
    decoration: reportCardDecoration(radius: 18),
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${data.rows.length} records',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: MohajonWarm.ink,
          ),
        ),
        const SizedBox(height: 12),
        for (final row in data.rows.take(100))
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${row[data.columns.first.key] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: MohajonWarm.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    row.entries.skip(1).map((e) => '${e.value}').join(' · '),
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: MohajonWarm.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
