import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/shop_profile.dart';
import '../../../core/models/sale.dart';
import '../../../core/services/invoice_service.dart';
import '../../../core/services/pdf_doc.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/snackbar.dart';
import '../../../core/widgets/async_action_state.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';
import '../../customers/providers/customer_providers.dart';
import '../../payments/presentation/add_payment_screen.dart';
import '../../settings/providers/shop_profile_providers.dart';
import '../../subscription/services/paywall_gate.dart';
import '../services/whatsapp_service.dart';

enum _SalesTimeFilter { allTime, today, thisWeek, thisMonth }
enum _InvoiceStatusFilter { all, paid, due, partial }

class SalesHistoryScreen extends ConsumerStatefulWidget {
  const SalesHistoryScreen({super.key, this.customer});

  final Customer? customer;

  @override
  ConsumerState<SalesHistoryScreen> createState() =>
      _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends ConsumerState<SalesHistoryScreen>
    with AsyncActionState<SalesHistoryScreen> {
  static const _pageSize = 20;
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  _SalesTimeFilter _timeFilter = _SalesTimeFilter.allTime;
  _InvoiceStatusFilter _statusFilter = _InvoiceStatusFilter.all;
  String _searchQuery = '';
  bool _showSearch = false;
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
    _searchController.dispose();
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

    return withLoadingOverlay(
      Theme(
        data: MohajonWarm.theme(Theme.of(context)),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: DecoratedBox(
            decoration: const BoxDecoration(gradient: MohajonWarm.pageGradient),
            child: SafeArea(
              child: RefreshIndicator(
                color: MohajonWarm.goldText,
                onRefresh: () async {
                  await ref.read(salesStreamProvider.future);
                },
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 96),
                  children: [
                    _TopBar(
                      subtitle: activeCustomer == null
                          ? 'Invoices & payments'
                          : _activeCustomerLabel(activeCustomer),
                    ),
                    if (activeCustomer != null) ...[
                      const SizedBox(height: 16),
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
                    const SizedBox(height: 18),
                    _SalesStats(stats: stats),
                    if (_showSearch) ...[
                      const SizedBox(height: 16),
                      _SearchPanel(
                        controller: _searchController,
                        query: _searchQuery,
                        timeFilter: _timeFilter,
                        statusFilter: _statusFilter,
                        onSearchChanged: (value) =>
                            setState(() => _searchQuery = value),
                        onClearSearch: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        onTimeChanged: (value) =>
                            setState(() => _timeFilter = value),
                        onStatusChanged: (value) =>
                            setState(() => _statusFilter = value),
                      ),
                    ],
                    const SizedBox(height: 18),
                    _SectionTitle(count: filteredSales.length),
                    const SizedBox(height: 12),
                    if (displaySales.isEmpty)
                      EmptyState(
                        message: _searchQuery.isEmpty &&
                                _timeFilter == _SalesTimeFilter.allTime &&
                                _statusFilter == _InvoiceStatusFilter.all
                            ? 'No sales have been recorded yet.'
                            : 'No invoices match your search.',
                        icon: _searchQuery.isEmpty
                            ? Icons.receipt_long_rounded
                            : Icons.search_off_rounded,
                      )
                    else
                      Column(
                        children: [
                          for (var index = 0;
                              index < displaySales.length;
                              index++) ...[
                            if (index != 0) const SizedBox(height: 10),
                            _InvoiceCard(
                              sale: displaySales[index],
                              customer:
                                  customerById[displaySales[index].customerId],
                              onTap: () => _openInvoiceSheet(
                                context,
                                sale: displaySales[index],
                                customer:
                                    customerById[displaySales[index].customerId],
                                profile: shopProfile,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          if (displaySales.length < filteredSales.length)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: MohajonWarm.goldText,
                                ),
                              ),
                            )
                          else
                            Text(
                              'Showing all ${filteredSales.length} invoices',
                              style: const TextStyle(
                                color: MohajonWarm.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.small(
            heroTag: 'sales-search',
            onPressed: () {
              setState(() => _showSearch = !_showSearch);
              if (!_showSearch) {
                _searchController.clear();
                _searchQuery = '';
              }
            },
            child: Icon(
              _showSearch ? Icons.search_off_rounded : Icons.search_rounded,
              size: 22,
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        ),
      ),
      label: 'Generating invoice...',
    );
  }

  List<Sale> _applyFilters(List<Sale> sales, Map<String, Customer> customerById) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfToday.subtract(Duration(days: now.weekday - 1));
    final startOfMonth = DateTime(now.year, now.month, 1);
    final query = _searchQuery.trim().toLowerCase();

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
      final customer = customerById[sale.customerId];
      final matchesSearch = query.isEmpty ||
          sale.saleId.toLowerCase().contains(query) ||
          (customer?.name.toLowerCase().contains(query) ?? false) ||
          (customer?.phone.contains(query) ?? false);
      return matchesTime && matchesStatus && matchesSearch;
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
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _InvoiceDetailSheet(
          sale: sale,
          customer: customer,
          profile: profile,
          onPrint: () async {
            Navigator.of(sheetContext).pop();
            await runBusyAction(() async {
              final bytes = await InvoiceService().buildSaleInvoice(
                sale,
                customerName: customer?.name ?? '',
                customerPhone: customer?.phone ?? '',
                company: DocCompany.fromShop(profile),
              );
              await Printing.sharePdf(
                bytes: bytes,
                filename: 'invoice-${sale.saleId}.pdf',
              );
            });
          },
          onRecordPayment: customer == null
              ? null
              : () {
                  Navigator.of(sheetContext).pop();
                  PaywallGate.guard(
                    context,
                    ref,
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AddPaymentScreen(customer: customer),
                      ),
                    ),
                  );
                },
          onSendBill: () {
            Navigator.of(sheetContext).pop();
            _sendBillOnWhatsapp(sale, customer, profile);
          },
        );
      },
    );
  }

  Future<void> _sendBillOnWhatsapp(
    Sale sale,
    Customer? customer,
    ShopProfile? profile,
  ) async {
    final l10n = AppLocalizations.of(context);
    final message = WhatsAppService.billMessage(
      sale: sale,
      shopName: profile?.shopName ?? '',
      customerName: customer?.name ?? '',
      t: (key) => l10n.t(key),
    );
    final ok = await WhatsAppService.openChat(
      phone: customer?.phone ?? '',
      message: message,
    );
    if (!ok && mounted) {
      showAppSnackBar(context, l10n.t('whatsappFailed'), isError: true);
    }
  }

  String _activeCustomerLabel(Customer customer) {
    return customer.phone.isEmpty
        ? customer.name
        : '${customer.name} • ${customer.phone}';
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
  const _TopBar({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return IconTheme(
      data: const IconThemeData(color: MohajonWarm.ink),
      child: Row(
        children: [
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
              Icons.receipt_long_rounded,
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
                  AppLocalizations.of(context).t('salesHistory'),
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
                    color: Color(0xFF77735F),
                  ),
                ),
              ],
            ),
          ),
          const NotificationBell(),
          const SizedBox(width: 14),
          const ShopAvatar(
            radius: 17,
            backgroundColor: Color(0xFFFFFDF7),
            textColor: MohajonWarm.ink,
          ),
        ],
      ),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: MohajonWarm.tintYellow,
            border: Border.all(color: MohajonWarm.goldBorder),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  customer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF5D4A00),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onClear,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: MohajonWarm.goldBorder),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 12,
                    color: MohajonWarm.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              allClear ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              size: 15,
              color: allClear ? MohajonWarm.green : MohajonWarm.red,
            ),
            const SizedBox(width: 5),
            Text(
              allClear
                  ? AppLocalizations.of(context).t('allClear')
                  : AppLocalizations.of(context).t('outstandingDues'),
              style: TextStyle(
                color: allClear ? MohajonWarm.green : MohajonWarm.red,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.controller,
    required this.query,
    required this.timeFilter,
    required this.statusFilter,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onTimeChanged,
    required this.onStatusChanged,
  });

  final TextEditingController controller;
  final String query;
  final _SalesTimeFilter timeFilter;
  final _InvoiceStatusFilter statusFilter;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<_SalesTimeFilter> onTimeChanged;
  final ValueChanged<_InvoiceStatusFilter> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
        children: [
          SizedBox(
            height: 46,
            child: TextField(
              controller: controller,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search invoice, phone, name...',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: MohajonWarm.muted,
                ),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: onClearSearch,
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: MohajonWarm.muted,
                        ),
                      ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: AppLocalizations.of(context).t('allTime'),
                  selected: timeFilter == _SalesTimeFilter.allTime,
                  onTap: () => onTimeChanged(_SalesTimeFilter.allTime),
                ),
                _FilterChip(
                  label: AppLocalizations.of(context).t('today'),
                  selected: timeFilter == _SalesTimeFilter.today,
                  onTap: () => onTimeChanged(_SalesTimeFilter.today),
                ),
                _FilterChip(
                  label: AppLocalizations.of(context).t('thisWeek'),
                  selected: timeFilter == _SalesTimeFilter.thisWeek,
                  onTap: () => onTimeChanged(_SalesTimeFilter.thisWeek),
                ),
                _FilterChip(
                  label: AppLocalizations.of(context).t('thisMonth'),
                  selected: timeFilter == _SalesTimeFilter.thisMonth,
                  onTap: () => onTimeChanged(_SalesTimeFilter.thisMonth),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: AppLocalizations.of(context).t('allInvoices'),
                  selected: statusFilter == _InvoiceStatusFilter.all,
                  onTap: () => onStatusChanged(_InvoiceStatusFilter.all),
                ),
                _FilterChip(
                  label: AppLocalizations.of(context).t('paid'),
                  selected: statusFilter == _InvoiceStatusFilter.paid,
                  onTap: () => onStatusChanged(_InvoiceStatusFilter.paid),
                ),
                _FilterChip(
                  label: AppLocalizations.of(context).t('due'),
                  selected: statusFilter == _InvoiceStatusFilter.due,
                  onTap: () => onStatusChanged(_InvoiceStatusFilter.due),
                ),
                _FilterChip(
                  label: AppLocalizations.of(context).t('partial'),
                  selected: statusFilter == _InvoiceStatusFilter.partial,
                  onTap: () => onStatusChanged(_InvoiceStatusFilter.partial),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.t('allInvoices'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
              color: MohajonWarm.ink,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: MohajonWarm.primary.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: MohajonWarm.primary.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            l10n.tP('invoicesCount', {'n': '$count'}),
            style: const TextStyle(
              color: Color(0xFF5D4A00),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _SalesStats extends StatelessWidget {
  const _SalesStats({required this.stats});

  final _SalesSummary stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        _RevenueCard(stats: stats),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isSingleColumn = constraints.maxWidth < 320;
            final cardWidth = isSingleColumn
                ? constraints.maxWidth
                : (constraints.maxWidth - 12) / 2;

            final cards = [
              _StatSpec(
                icon: Icons.receipt_long_rounded,
                label: l10n.t('invoices'),
                value: '${stats.count}',
                subtext: l10n.tP('paidInFullCount', {'n': '${stats.paidCount}'}),
                color: MohajonWarm.goldText,
                background: MohajonWarm.tintYellow,
              ),
              _StatSpec(
                icon: Icons.error_outline_rounded,
                label: l10n.t('outstanding'),
                value: money(stats.outstanding),
                subtext: l10n.tP('pendingCount', {'count': '${stats.dueCount}'}),
                color: MohajonWarm.red,
                background: MohajonWarm.tintRed,
              ),
            ];

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final card in cards)
                  SizedBox(width: cardWidth, child: _StatCard(spec: card)),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({required this.stats});

  final _SalesSummary stats;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MohajonWarm.tintGreen, MohajonWarm.card],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MohajonWarm.goldBorder),
        boxShadow: [
          BoxShadow(
            color: MohajonWarm.green.withValues(alpha: 0.09),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: MohajonWarm.green.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.trending_up_rounded,
              color: MohajonWarm.green,
              size: 19,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      AppLocalizations.of(context).t('totalRevenue'),
                      style: const TextStyle(
                        color: MohajonWarm.green,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        AppLocalizations.of(context)
                            .tP('acrossInvoices', {'n': '${stats.count}'}),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    money(stats.totalRevenue),
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 22,
                      color: colors.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _MiniPill(
                      icon: Icons.south_west_rounded,
                      label: 'Collected ${money(stats.collected)}',
                      color: MohajonWarm.green,
                      background: MohajonWarm.tintGreen,
                    ),
                    const SizedBox(width: 6),
                    if (!stats.allClear)
                      _MiniPill(
                        icon: Icons.north_east_rounded,
                        label: 'Due ${money(stats.outstanding)}',
                        color: MohajonWarm.red,
                        background: MohajonWarm.tintRed,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatSpec {
  const _StatSpec({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtext,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final String label;
  final String value;
  final String subtext;
  final Color color;
  final Color background;
}

/// Matches the Home / Stock / Clients stat card styling.
class _StatCard extends StatelessWidget {
  const _StatCard({required this.spec});

  final _StatSpec spec;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 130,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [spec.background, MohajonWarm.card],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MohajonWarm.goldBorder),
        boxShadow: [
          BoxShadow(
            color: spec.color.withValues(alpha: 0.09),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: spec.color.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(spec.icon, color: spec.color, size: 16),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: spec.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    spec.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: spec.color,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              spec.value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 20,
                color: colors.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            spec.subtext,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? MohajonWarm.primary : Colors.white,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? MohajonWarm.primary.withValues(alpha: 0.45)
                    : MohajonWarm.goldBorder,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFF5D4A00) : MohajonWarm.muted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
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
    final l10n = AppLocalizations.of(context);
    final statusColor = _statusColor(sale.paymentStatus);
    final statusBg = _statusBackground(sale.paymentStatus);

    return Material(
      color: MohajonWarm.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: MohajonWarm.goldBorder),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: MohajonWarm.ink.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 340;
              final titleBlock = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _invoiceNumber(sale.saleId),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: MohajonWarm.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    customer?.name ?? l10n.t('walkIn'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: MohajonWarm.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );

              final trailingBlock = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    money(sale.totalAmount),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: MohajonWarm.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                     _statusLabel(sale.paymentStatus, l10n),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${l10n.tP('itemsCount', {'n': '${sale.items.length}'})} • ${_formatInvoiceTime(sale.createdAt, l10n)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: MohajonWarm.muted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _leadingIcon(),
                        const SizedBox(width: 10),
                        Expanded(child: titleBlock),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Align(alignment: Alignment.centerRight, child: trailingBlock),
                  ],
                );
              }

              return Row(
                children: [
                  _leadingIcon(),
                  const SizedBox(width: 12),
                  Expanded(child: titleBlock),
                  const SizedBox(width: 10),
                  trailingBlock,
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _leadingIcon() => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFE9CF), Color(0xFFFCD9AE)],
          ),
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Icon(
          Icons.receipt_long_rounded,
          color: Color(0xFFE98300),
          size: 20,
        ),
      );
}

class _InvoiceDetailSheet extends StatelessWidget {
  const _InvoiceDetailSheet({
    required this.sale,
    required this.customer,
    required this.profile,
    required this.onPrint,
    required this.onRecordPayment,
    required this.onSendBill,
  });

  final Sale sale;
  final Customer? customer;
  final ShopProfile? profile;
  final VoidCallback onPrint;
  final VoidCallback? onRecordPayment;
  final VoidCallback onSendBill;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = _statusLabel(sale.paymentStatus, l10n);
    final statusColor = _statusColor(sale.paymentStatus);
    final statusBg = _statusBackground(sale.paymentStatus);
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
            color: MohajonWarm.surface,
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
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: MohajonWarm.goldBorder,
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
                            _invoiceNumber(sale.saleId),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: MohajonWarm.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            DateFormat('MMM d, y').format(sale.createdAt),
                            style: const TextStyle(
                              color: MohajonWarm.muted,
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
                        color: statusBg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.25),
                        ),
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
                      icon: const Icon(
                        Icons.close_rounded,
                        color: MohajonWarm.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryTile(
                        title: l10n.t('customer'),
                        value: customer?.name ?? l10n.t('walkIn'),
                        valueColor: MohajonWarm.ink,
                        background: MohajonWarm.tintYellow,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryTile(
                        title: l10n.t('payment'),
                        value: status.toUpperCase(),
                        valueColor: statusColor,
                        background: statusBg,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n
                            .tP('itemsLabel', {'n': '${sale.items.length}'})
                            .toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: MohajonWarm.ink,
                        ),
                      ),
                    ),
                    Text(
                      '${sale.items.length} total',
                      style: const TextStyle(
                        color: MohajonWarm.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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
                      color: MohajonWarm.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: MohajonWarm.goldBorder),
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
                                  color: MohajonWarm.ink,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${_formatQuantity(item.qty)} × ${money(item.unitPrice)}',
                                style: const TextStyle(
                                  color: MohajonWarm.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
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
                            color: MohajonWarm.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Divider(height: 24),
                _AmountRow(label: l10n.t('subtotal'), value: money(subtotal)),
                _AmountRow(
                  label: l10n.t('discount'),
                  value: money(sale.discount),
                ),
                const SizedBox(height: 6),
                _AmountRow(
                  label: l10n.t('total'),
                  value: money(sale.totalAmount),
                  bold: true,
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: MohajonWarm.ink,
                          side: const BorderSide(color: MohajonWarm.goldBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        onPressed: onPrint,
                        icon: const Icon(Icons.print_rounded),
                        label: Text(
                          l10n.t('printInvoice'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: MohajonWarm.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        onPressed: onRecordPayment,
                        icon: const Icon(Icons.payments_outlined),
                        label: Text(
                          l10n.t('recordPayment'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                if (customer?.phone.isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: onSendBill,
                      icon: const Icon(Icons.chat_rounded, size: 19),
                      label: Text(
                        AppLocalizations.of(context).t('sendBillOnWhatsapp'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
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
        border: Border.all(color: MohajonWarm.goldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: MohajonWarm.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
                color: bold ? MohajonWarm.ink : MohajonWarm.muted,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: bold ? MohajonWarm.ink : MohajonWarm.muted,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
              fontSize: bold ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

String _invoiceNumber(String saleId) {
  final length = saleId.length < 5 ? saleId.length : 5;
  return 'INV-${saleId.substring(0, length).toUpperCase()}';
}

String _statusLabel(PaymentStatus status, AppLocalizations l10n) {
  return switch (status) {
    PaymentStatus.paid => l10n.t('paid'),
    PaymentStatus.partial => l10n.t('partial'),
    PaymentStatus.due => l10n.t('due'),
  };
}

Color _statusColor(PaymentStatus status) {
  return switch (status) {
    PaymentStatus.paid => MohajonWarm.green,
    PaymentStatus.partial => MohajonWarm.orange,
    PaymentStatus.due => MohajonWarm.red,
  };
}

Color _statusBackground(PaymentStatus status) {
  return switch (status) {
    PaymentStatus.paid => MohajonWarm.tintGreen,
    PaymentStatus.partial => MohajonWarm.tintOrange,
    PaymentStatus.due => MohajonWarm.tintRed,
  };
}

String _formatQuantity(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

String _formatInvoiceTime(DateTime time, AppLocalizations l10n) {
  final now = DateTime.now();
  final diff = now.difference(time);
  if (diff.inDays == 0) return l10n.t('today');
  if (diff.inDays == 1) return l10n.t('yesterday');
  if (diff.inDays < 7) {
    return l10n.tP('daysAgo', {'n': '${diff.inDays}'});
  }
  return DateFormat('MMM d').format(time);
}
