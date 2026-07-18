import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/shop_profile.dart';
import '../../../core/models/sale.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';
import '../../customers/presentation/customer_form_screen.dart';
import '../../customers/providers/customer_providers.dart';
import '../../payments/presentation/add_payment_screen.dart';
import '../../receipts/models/receipt.dart';
import '../../receipts/presentation/receipt_preview_screen.dart';
import '../../settings/providers/shop_profile_providers.dart';

enum _SalesTimeFilter { allTime, today, thisWeek, thisMonth }
enum _InvoiceStatusFilter { all, paid, due, partial }

class SalesHistoryScreen extends ConsumerStatefulWidget {
  const SalesHistoryScreen({super.key, this.customer});

  final Customer? customer;

  @override
  ConsumerState<SalesHistoryScreen> createState() =>
      _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends ConsumerState<SalesHistoryScreen> {
  static const _pageSize = 20;
  final _scrollController = ScrollController();
  _SalesTimeFilter _timeFilter = _SalesTimeFilter.allTime;
  _InvoiceStatusFilter _statusFilter = _InvoiceStatusFilter.all;
  int _loadedCount = _pageSize;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      setState(() => _loadedCount += _pageSize);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sales = ref.watch(salesStreamProvider).value ?? const <Sale>[];
    final customers = ref.watch(customersProvider).value ?? const <Customer>[];
    final shopProfile = ref.watch(shopProfileProvider).value;
    final customerById = {
      for (final customer in customers) customer.customerId: customer,
    };

    final scopedSales = widget.customer == null
        ? sales
        : sales.where((sale) => sale.customerId == widget.customer!.customerId).toList();
    final stats = _summary(scopedSales);
    final activeCustomer = widget.customer;

    final filteredSales = _applyFilters(scopedSales, customerById);
    final displaySales = filteredSales.take(_loadedCount).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5EF),
      body: SafeArea(
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _TopBar(
              title: 'Sales History',
              customerLabel: activeCustomer == null
                  ? null
                  : _activeCustomerLabel(activeCustomer),
              clearLabel: stats.allClear ? 'All clear' : null,
              onClearCustomer: activeCustomer == null
                  ? null
                  : () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const SalesHistoryScreen(),
                        ),
                      ),
            ),
            if (activeCustomer != null) ...[
              const SizedBox(height: 14),
              _ActiveCustomerChip(
                customer: activeCustomer,
                allClear: stats.allClear,
                onClear: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const SalesHistoryScreen(),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MiniStatCard(
                    label: 'Invoices',
                    value: '${stats.count}',
                    subtext: 'Filtered',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniStatCard(
                    label: 'Total Revenue',
                    value: money(stats.totalRevenue),
                    subtext: 'Filtered',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniStatCard(
                    label: 'Collected',
                    value: money(stats.collected),
                    subtext: '${stats.paidCount} paid\ninvoices',
                    accent: const Color(0xFF0F766E),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniStatCard(
                    label: 'Outstanding',
                    value: money(stats.outstanding),
                    subtext: '${stats.dueCount}\npending',
                    accent: const Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE8E4DB)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _PillChip(
                        label: 'All Time',
                        selected: _timeFilter == _SalesTimeFilter.allTime,
                        onTap: () => setState(
                          () => _timeFilter = _SalesTimeFilter.allTime,
                        ),
                      ),
                      _PillChip(
                        label: 'Today',
                        selected: _timeFilter == _SalesTimeFilter.today,
                        onTap: () => setState(
                          () => _timeFilter = _SalesTimeFilter.today,
                        ),
                      ),
                      _PillChip(
                        label: 'This Week',
                        selected: _timeFilter == _SalesTimeFilter.thisWeek,
                        onTap: () => setState(
                          () => _timeFilter = _SalesTimeFilter.thisWeek,
                        ),
                      ),
                      _PillChip(
                        label: 'This Month',
                        selected: _timeFilter == _SalesTimeFilter.thisMonth,
                        onTap: () => setState(
                          () => _timeFilter = _SalesTimeFilter.thisMonth,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _PillChip(
                        label: 'All',
                        selected: _statusFilter == _InvoiceStatusFilter.all,
                        dark: true,
                        onTap: () => setState(
                          () => _statusFilter = _InvoiceStatusFilter.all,
                        ),
                      ),
                      _PillChip(
                        label: 'Paid',
                        selected: _statusFilter == _InvoiceStatusFilter.paid,
                        dark: true,
                        onTap: () => setState(
                          () => _statusFilter = _InvoiceStatusFilter.paid,
                        ),
                      ),
                      _PillChip(
                        label: 'Due',
                        selected: _statusFilter == _InvoiceStatusFilter.due,
                        dark: true,
                        onTap: () => setState(
                          () => _statusFilter = _InvoiceStatusFilter.due,
                        ),
                      ),
                      _PillChip(
                        label: 'Partial',
                        selected: _statusFilter == _InvoiceStatusFilter.partial,
                        dark: true,
                        onTap: () => setState(
                          () => _statusFilter = _InvoiceStatusFilter.partial,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (displaySales.isEmpty)
              const EmptyState(
                message: 'No sales have been recorded yet.',
                icon: Icons.receipt_long_rounded,
              )
            else
              Column(
                children: [
                  for (var index = 0; index < displaySales.length; index++) ...[
                    if (index != 0) const SizedBox(height: 10),
                    _InvoiceCard(
                      sale: displaySales[index],
                      customer: customerById[displaySales[index].customerId],
                      onTap: () => _openInvoiceSheet(
                        context,
                        sale: displaySales[index],
                        customer: customerById[displaySales[index].customerId],
                        profile: shopProfile,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  if (displaySales.length < filteredSales.length)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    Text(
                      'Showing all ${filteredSales.length} invoices',
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  List<Sale> _applyFilters(List<Sale> sales, Map<String, Customer> customerById) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfToday.subtract(Duration(days: now.weekday - 1));
    final startOfMonth = DateTime(now.year, now.month, 1);

    return sales.where((sale) {
      final matchesTime = switch (_timeFilter) {
        _SalesTimeFilter.allTime => true,
        _SalesTimeFilter.today =>
          !sale.createdAt.isBefore(startOfToday),
        _SalesTimeFilter.thisWeek =>
          !sale.createdAt.isBefore(startOfWeek),
        _SalesTimeFilter.thisMonth =>
          !sale.createdAt.isBefore(startOfMonth),
      };
      final matchesStatus = switch (_statusFilter) {
        _InvoiceStatusFilter.all => true,
        _InvoiceStatusFilter.paid => sale.paymentStatus == PaymentStatus.paid,
        _InvoiceStatusFilter.due => sale.paymentStatus == PaymentStatus.due,
        _InvoiceStatusFilter.partial =>
          sale.paymentStatus == PaymentStatus.partial,
      };
      return matchesTime && matchesStatus;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  _SalesSummary _summary(List<Sale> sales) {
    final count = sales.length;
    final totalRevenue = sales.fold<double>(0, (sum, sale) => sum + sale.totalAmount);
    final collected = sales.fold<double>(
      0,
      (sum, sale) => sum + sale.paidAmount,
    );
    final outstanding = sales.fold<double>(
      0,
      (sum, sale) => sum + sale.dueAmount,
    );
    final paidCount = sales.where((sale) => sale.paymentStatus == PaymentStatus.paid).length;
    final dueCount = sales.where((sale) => sale.paymentStatus == PaymentStatus.due).length;
    return _SalesSummary(
      count: count,
      totalRevenue: totalRevenue,
      collected: collected,
      outstanding: outstanding,
      paidCount: paidCount,
      dueCount: dueCount,
    );
  }

  void _openInvoiceSheet(
    BuildContext context, {
    required Sale sale,
    required Customer? customer,
    required ShopProfile? profile,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _InvoiceDetailSheet(
          sale: sale,
          customer: customer,
          profile: profile,
          onPrint: () {
            Navigator.of(sheetContext).pop();
            final receipt = _buildReceipt(sale, customer, profile);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ReceiptPreviewScreen(receipt: receipt),
              ),
            );
          },
          onRecordPayment: customer == null
              ? null
              : () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AddPaymentScreen(customer: customer),
                    ),
                  );
                },
        );
      },
    );
  }

  Receipt _buildReceipt(Sale sale, Customer? customer, ShopProfile? profile) {
    final shopName = profile?.shopName.trim().isNotEmpty == true
        ? profile!.shopName.trim()
        : 'Haalkhata';
    final address = profile?.location.trim().isNotEmpty == true
        ? profile!.location.trim()
        : 'Dhaka, Bangladesh';
    final phone = profile?.phoneNumber.trim().isNotEmpty == true
        ? profile!.phoneNumber.trim()
        : '+880 1712-345678';

    return Receipt(
      companyName: shopName,
      companyAddress: address,
      companyPhone: phone,
      customerId: customer?.customerId ?? sale.customerId,
      customerName: customer?.name.isNotEmpty == true
          ? customer!.name
          : 'Walk-in customer',
      customerPhone: customer?.phone.isNotEmpty == true ? customer!.phone : '',
      receiptNumber: sale.saleId,
      paymentMethod: PaymentMethod.cash,
      items: [
        for (final item in sale.items)
          ReceiptItem(
            id: item.productId.isEmpty ? item.name : item.productId,
            productId: item.productId,
            description: item.name,
            quantity: item.qty,
            price: item.unitPrice,
            purchasePrice: item.purchasePrice,
          ),
      ],
      discountType: ReceiptDiscountType.fixedAmount,
      discountPercent: 0,
      discountFixedAmount: sale.discount,
      taxPercent: 0,
      date: sale.createdAt,
    );
  }

  String _activeCustomerLabel(Customer customer) {
    return '${customer.name} • ${customer.phone.isEmpty ? 'No phone' : customer.phone}';
  }
}

class _SalesSummary {
  const _SalesSummary({
    required this.count,
    required this.totalRevenue,
    required this.collected,
    required this.outstanding,
    required this.paidCount,
    required this.dueCount,
  });

  final int count;
  final double totalRevenue;
  final double collected;
  final double outstanding;
  final int paidCount;
  final int dueCount;

  bool get allClear => outstanding <= 0;
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    this.customerLabel,
    this.clearLabel,
    this.onClearCustomer,
  });

  final String title;
  final String? customerLabel;
  final String? clearLabel;
  final VoidCallback? onClearCustomer;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFFE98300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.storefront_rounded,
            color: Colors.white,
            size: 17,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF101828),
            ),
          ),
        ),
        const NotificationBell(),
        const SizedBox(width: 14),
        const ShopAvatar(radius: 16),
      ],
    );
  }
}

class _ActiveCustomerChip extends StatelessWidget {
  const _ActiveCustomerChip({
    required this.customer,
    required this.allClear,
    required this.onClear,
  });

  final Customer customer;
  final bool allClear;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF6E7D1),
            border: Border.all(color: const Color(0xFFE3C08D)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _initials(customer.name),
                style: const TextStyle(
                  color: Color(0xFFE98300),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                customer.name,
                style: const TextStyle(
                  color: Color(0xFFE98300),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: onClear,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE9D2A9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, size: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          allClear ? 'All clear' : 'Outstanding',
          style: const TextStyle(
            color: Color(0xFF667085),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty);
    final initials = parts
        .take(2)
        .map((part) => part.substring(0, 1).toUpperCase())
        .join();
    return initials.isEmpty ? '?' : initials;
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.subtext,
    this.accent = const Color(0xFFE98300),
  });

  final String label;
  final String value;
  final String subtext;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE8E4DB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF667085),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          Text(
            subtext,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PillChip extends StatelessWidget {
  const _PillChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.dark = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final selectedColor = dark ? const Color(0xFF101828) : const Color(0xFFE98300);
    final unselectedColor = dark ? const Color(0xFFF3F0EA) : const Color(0xFFF7F5F0);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? selectedColor : unselectedColor,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF101828),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({
    required this.sale,
    required this.customer,
    required this.onTap,
  });

  final Sale sale;
  final Customer? customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = _statusLabel(sale.paymentStatus);
    final statusColor = _statusColor(sale.paymentStatus);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F0EA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Color(0xFFE98300),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'INV-${sale.saleId.substring(0, sale.saleId.length < 5 ? sale.saleId.length : 5).toUpperCase()}',
                      style: const TextStyle(
                        color: Color(0xFF101828),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      customer?.name ?? 'Walk-in customer',
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    money(sale.totalAmount),
                    style: const TextStyle(
                      color: Color(0xFF101828),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${sale.items.length} items • ${_formatInvoiceTime(sale.createdAt)}',
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvoiceDetailSheet extends StatelessWidget {
  const _InvoiceDetailSheet({
    required this.sale,
    required this.customer,
    required this.profile,
    required this.onPrint,
    required this.onRecordPayment,
  });

  final Sale sale;
  final Customer? customer;
  final ShopProfile? profile;
  final VoidCallback onPrint;
  final VoidCallback? onRecordPayment;

  @override
  Widget build(BuildContext context) {
    final status = _statusLabel(sale.paymentStatus);
    final statusColor = _statusColor(sale.paymentStatus);
    final subtotal = sale.items.fold<double>(
      0,
      (sum, item) => sum + item.lineTotal,
    );
    return DraggableScrollableSheet(
      initialChildSize: 0.93,
      minChildSize: 0.72,
      maxChildSize: 0.97,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'INV-${sale.saleId.substring(0, sale.saleId.length < 5 ? sale.saleId.length : 5).toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            DateFormat('MMM d, y').format(sale.createdAt),
                            style: const TextStyle(color: Color(0xFF667085)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryTile(
                        title: 'Customer',
                        value: customer?.name ?? 'Walk-in customer',
                        valueColor: const Color(0xFF101828),
                        background: const Color(0xFFF7F7EF),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryTile(
                        title: 'Payment',
                        value: sale.paymentStatus.name.toUpperCase(),
                        valueColor: const Color(0xFF101828),
                        background: const Color(0xFFF7F7EF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'ITEMS (${sale.items.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF101828),
                        ),
                      ),
                    ),
                    Text(
                      '${sale.items.length} total',
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final item in sale.items) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F6F1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF101828),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${_formatQuantity(item.qty)} × ${money(item.unitPrice)}',
                                style: const TextStyle(
                                  color: Color(0xFF667085),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          money(item.lineTotal),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Divider(height: 24),
                _AmountRow(label: 'Subtotal', value: money(subtotal)),
                _AmountRow(label: 'Discount', value: money(sale.discount)),
                const SizedBox(height: 6),
                _AmountRow(
                  label: 'Total',
                  value: money(sale.totalAmount),
                  bold: true,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF97316),
                        ),
                        onPressed: onPrint,
                        icon: const Icon(Icons.print_rounded),
                        label: const Text('Print Invoice'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                        ),
                        onPressed: onRecordPayment,
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text('Record Payment'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.title,
    required this.value,
    required this.valueColor,
    required this.background,
  });

  final String title;
  final String value;
  final Color valueColor;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF667085),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: bold ? const Color(0xFF101828) : const Color(0xFF667085),
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: bold ? const Color(0xFF101828) : const Color(0xFF667085),
              fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
              fontSize: bold ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

String _statusLabel(PaymentStatus status) {
  return switch (status) {
    PaymentStatus.paid => 'Paid',
    PaymentStatus.partial => 'Partial',
    PaymentStatus.due => 'Due',
  };
}

Color _statusColor(PaymentStatus status) {
  return switch (status) {
    PaymentStatus.paid => const Color(0xFF0F766E),
    PaymentStatus.partial => const Color(0xFFF97316),
    PaymentStatus.due => const Color(0xFFEF4444),
  };
}

String _formatQuantity(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

String _formatInvoiceTime(DateTime time) {
  final now = DateTime.now();
  final diff = now.difference(time);
  if (diff.inDays == 0) return 'Today';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return DateFormat('MMM d').format(time);
}
