import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../models/vendor.dart';
import '../providers/vendor_providers.dart';
import 'vendor_detail_screen.dart';
import 'vendor_form_screen.dart';
import '../../subscription/services/paywall_gate.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';

class VendorListScreen extends ConsumerStatefulWidget {
  const VendorListScreen({super.key});

  @override
  ConsumerState<VendorListScreen> createState() => _VendorListScreenState();
}

class _VendorListScreenState extends ConsumerState<VendorListScreen> {
  late final TextEditingController _searchController;
  VendorSort _sort = VendorSort.newest;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final vendorsAsync = ref.watch(vendorsProvider);
    final searchQuery = ref.watch(vendorSearchQueryProvider);
    final selectedCategory = ref.watch(vendorCategoryFilterProvider);

    return Theme(
      data: MohajonWarm.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: MohajonWarm.pageGradient,
          ),
          child: SafeArea(
            child: vendorsAsync.when(
              data: (items) {
                final filtered = ref.watch(filteredVendorsProvider);
                final totalSpent = items.fold<double>(
                  0,
                  (s, v) => s + v.totalSpent,
                );
                final totalPending = items.fold<double>(
                  0,
                  (s, v) => s + v.pendingAmount,
                );

                return RefreshIndicator(
                  color: MohajonWarm.goldText,
                  onRefresh: () async {
                    await ref.read(vendorsProvider.future);
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 96),
                    children: [
                      const _VendorsTopBar(),
                      const SizedBox(height: 18),
                      _VendorStats(
                        totalVendors: items.length,
                        totalSpent: totalSpent,
                        totalPending: totalPending,
                      ),
                      if (_showSearch) ...[
                        const SizedBox(height: 16),
                        _SearchAndFilters(
                          controller: _searchController,
                          searchQuery: searchQuery,
                          selectedSort: _sort,
                          selectedCategory: selectedCategory,
                          onSearchChanged: (value) =>
                              ref
                                  .read(vendorSearchQueryProvider.notifier)
                                  .state = value,
                          onClearSearch: () {
                            _searchController.clear();
                            ref
                                .read(vendorSearchQueryProvider.notifier)
                                .state = '';
                          },
                          onSortChanged: (sort) {
                            setState(() => _sort = sort);
                            ref.read(vendorSortProvider.notifier).state =
                                sort;
                          },
                          onCategoryChanged: (cat) =>
                              ref
                                  .read(vendorCategoryFilterProvider.notifier)
                                  .state = cat,
                        ),
                      ],
                      const SizedBox(height: 18),
                      if (items.isEmpty)
                        EmptyState(
                          message: l10n.t('addVendorsEmpty'),
                          icon: Icons.store_outlined,
                        )
                      else if (filtered.isEmpty)
                        EmptyState(
                          message: l10n.t('noVendorsMatch'),
                          icon: Icons.search_off_rounded,
                        )
                      else
                        _VendorList(
                          vendors: filtered,
                          onVendorTap: (vendor) =>
                              _openVendorDetail(vendor),
                        ),
                    ],
                  ),
                );
              },
              error: (error, _) => EmptyState(message: error.toString()),
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: MohajonWarm.primary,
                ),
              ),
            ),
          ),
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.small(
              heroTag: 'vendorSearch',
              onPressed: () {
                setState(() => _showSearch = !_showSearch);
                if (!_showSearch) {
                  _searchController.clear();
                  ref.read(vendorSearchQueryProvider.notifier).state = '';
                }
              },
              child: Icon(
                _showSearch
                    ? Icons.search_off_rounded
                    : Icons.search_rounded,
                size: 22,
              ),
            ),
            const SizedBox(height: 8),
            FloatingActionButton(
              heroTag: 'vendorAdd',
              onPressed: _openAddVendor,
              child: const Icon(Icons.add_rounded, size: 26),
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  void _openAddVendor() {
    PaywallGate.guardPro(
      context,
      ref,
      () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const VendorFormScreen())),
    );
  }

  void _openVendorDetail(Vendor vendor) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VendorDetailScreen(vendor: vendor)),
    );
  }
}

class _VendorsTopBar extends StatelessWidget {
  const _VendorsTopBar();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                  l10n.t('vendors'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: MohajonWarm.ink,
                  ),
                ),
                Text(
                  l10n.t('suppliersAndPurchases'),
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

class _VendorStats extends StatelessWidget {
  const _VendorStats({
    required this.totalVendors,
    required this.totalSpent,
    required this.totalPending,
  });

  final int totalVendors;
  final double totalSpent;
  final double totalPending;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _VendorStatCard(
                spec: _VendorStatSpec(
                  icon: Icons.storefront_rounded,
                  label: l10n.t('vendors'),
                  value: '$totalVendors',
                  subtext: l10n.t('activeSuppliers'),
                  color: MohajonWarm.goldText,
                  background: MohajonWarm.tintYellow,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _VendorStatCard(
                spec: _VendorStatSpec(
                  icon: Icons.shopping_cart_rounded,
                  label: l10n.t('totalSpent'),
                  value: money(totalSpent),
                  subtext: l10n.t('acrossAllVendors'),
                  color: MohajonWarm.green,
                  background: MohajonWarm.tintGreen,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _PendingPaymentCard(
          value: money(totalPending),
          hasPending: totalPending > 0,
        ),
      ],
    );
  }
}

class _VendorStatSpec {
  const _VendorStatSpec({
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

/// Matches the Home screen stat card styling.
class _VendorStatCard extends StatelessWidget {
  const _VendorStatCard({required this.spec});

  final _VendorStatSpec spec;

  @override
  Widget build(BuildContext context) {
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
              style: const TextStyle(
                fontSize: 20,
                color: MohajonWarm.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            spec.subtext,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: MohajonWarm.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingPaymentCard extends StatelessWidget {
  const _PendingPaymentCard({required this.value, required this.hasPending});

  final String value;
  final bool hasPending;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = hasPending ? MohajonWarm.red : MohajonWarm.green;
    final background = hasPending
        ? MohajonWarm.tintRed
        : MohajonWarm.tintGreen;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [background, MohajonWarm.card],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MohajonWarm.goldBorder),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.09),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      hasPending
                          ? l10n.t('pendingPayment')
                          : l10n.t('allCleared'),
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      hasPending
                          ? l10n.t('needsSettlement')
                          : l10n.t('noDues'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MohajonWarm.muted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 22,
                      color: MohajonWarm.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(Icons.payments_rounded, color: color, size: 19),
          ),
        ],
      ),
    );
  }
}

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.controller,
    required this.searchQuery,
    required this.selectedSort,
    required this.selectedCategory,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onSortChanged,
    required this.onCategoryChanged,
  });

  final TextEditingController controller;
  final String searchQuery;
  final VendorSort selectedSort;
  final String selectedCategory;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<VendorSort> onSortChanged;
  final ValueChanged<String> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: TextField(
                    controller: controller,
                    onChanged: onSearchChanged,
                    decoration: InputDecoration(
                      hintText: l10n.t('searchCompany'),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: MohajonWarm.muted,
                      ),
                      suffixIcon: searchQuery.isEmpty
                          ? null
                          : IconButton(
                              onPressed: onClearSearch,
                              icon: const Icon(
                                Icons.close_rounded,
                                color: MohajonWarm.muted,
                              ),
                            ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              DropdownButtonHideUnderline(
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: MohajonWarm.goldBorder),
                  ),
                  child: DropdownButton<VendorSort>(
                    value: selectedSort,
                    underline: const SizedBox.shrink(),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: MohajonWarm.muted,
                    ),
                    style: const TextStyle(
                      color: MohajonWarm.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: VendorSort.newest,
                        child: Text(l10n.t('newest')),
                      ),
                      DropdownMenuItem(
                        value: VendorSort.oldest,
                        child: Text(l10n.t('oldest')),
                      ),
                      DropdownMenuItem(
                        value: VendorSort.highestDue,
                        child: Text(l10n.t('highestDue')),
                      ),
                      DropdownMenuItem(
                        value: VendorSort.lowestDue,
                        child: Text(l10n.t('lowestDue')),
                      ),
                      DropdownMenuItem(
                        value: VendorSort.mostOrders,
                        child: Text(l10n.t('mostOrders')),
                      ),
                      DropdownMenuItem(
                        value: VendorSort.highestPurchase,
                        child: Text(l10n.t('highestPurchase')),
                      ),
                      DropdownMenuItem(
                        value: VendorSort.alphabetical,
                        child: Text(l10n.t('aToZ')),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) onSortChanged(value);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: vendorCategories.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _FilterChip(
                    label: l10n.t('all'),
                    selected: selectedCategory.isEmpty,
                    onTap: () => onCategoryChanged(''),
                  );
                }
                final cat = vendorCategories[index - 1];
                return _FilterChip(
                  label: cat,
                  selected: selectedCategory == cat,
                  onTap: () =>
                      onCategoryChanged(selectedCategory == cat ? '' : cat),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill chip matching the Stock filter chips.
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
                color: selected
                    ? const Color(0xFF5D4A00)
                    : MohajonWarm.muted,
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

class _VendorList extends StatelessWidget {
  const _VendorList({
    required this.vendors,
    required this.onVendorTap,
  });

  final List<Vendor> vendors;
  final ValueChanged<Vendor> onVendorTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < vendors.length; index++) ...[
          if (index != 0) const SizedBox(height: 10),
          _VendorCard(
            vendor: vendors[index],
            onTap: () => onVendorTap(vendors[index]),
          ),
        ],
      ],
    );
  }
}

class _VendorCard extends ConsumerStatefulWidget {
  const _VendorCard({
    required this.vendor,
    required this.onTap,
  });

  final Vendor vendor;
  final VoidCallback onTap;

  @override
  ConsumerState<_VendorCard> createState() => _VendorCardState();
}

class _VendorCardState extends ConsumerState<_VendorCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final vendor = widget.vendor;
    final initials = _initials(vendor.companyName);
    final hasDue = vendor.pendingAmount > 0;

    return Material(
      color: MohajonWarm.card,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onTap,
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFFE9CF), Color(0xFFFCD9AE)],
                      ),
                      borderRadius: BorderRadius.all(Radius.circular(13)),
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Color(0xFFE98300),
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                vendor.companyName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: MohajonWarm.ink,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (hasDue)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: MohajonWarm.tintRed,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  l10n.t('due'),
                                  style: const TextStyle(
                                    color: MohajonWarm.red,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          vendor.contactPerson,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        money(vendor.totalSpent),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: MohajonWarm.ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: hasDue
                              ? MohajonWarm.tintOrange
                              : MohajonWarm.tintGreen,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          hasDue
                              ? l10n.tP('vendorDueAmount', {'n': money(vendor.pendingAmount)})
                              : l10n.t('cleared'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: hasDue
                                ? MohajonWarm.orange
                                : MohajonWarm.green,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        vendor.lastPurchaseDate != null
                            ? _formatDate(vendor.lastPurchaseDate!,
                                l10n)
                            : l10n.t('noPurchases'),
                        style: const TextStyle(
                          color: MohajonWarm.muted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _expanded = !_expanded),
                    child: AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: MohajonWarm.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _VendorExpandedDetails(vendor: vendor),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt, AppLocalizations l10n) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return l10n.t('today');
    if (diff.inDays == 1) return l10n.t('yesterday');
    return l10n.tP('daysAgo', {'n': '${diff.inDays}'});
  }
}

class _VendorExpandedDetails extends ConsumerWidget {
  const _VendorExpandedDetails({required this.vendor});
  final Vendor vendor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final outstanding = ref.watch(
      vendorOutstandingProvider(vendor.vendorId),
    );
    final purchases = ref.watch(
      vendorPurchasesForVendorProvider(vendor.vendorId),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: MohajonWarm.goldBorder),
          right: BorderSide(color: MohajonWarm.goldBorder),
          bottom: BorderSide(color: MohajonWarm.goldBorder),
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, color: Color(0xFFF3ECDA)),
          const SizedBox(height: 12),
          if (vendor.phone.isNotEmpty)
            _InfoRow(icon: Icons.phone_outlined, text: vendor.phone),
          if (vendor.email.isNotEmpty)
            _InfoRow(icon: Icons.email_outlined, text: vendor.email),
          if (vendor.address.isNotEmpty)
            _InfoRow(icon: Icons.location_on_outlined, text: vendor.address),
          if (vendor.products.isNotEmpty)
            _InfoRow(icon: Icons.category_outlined, text: vendor.products),
          const SizedBox(height: 10),
          Row(
            children: [
              _MiniStat(
                label: l10n.t('orders'),
                value: '${purchases.length}',
                color: MohajonWarm.goldText,
                background: MohajonWarm.tintYellow,
              ),
              const SizedBox(width: 8),
              _MiniStat(
                label: l10n.t('totalSpent'),
                value: money(vendor.totalSpent),
                color: MohajonWarm.green,
                background: MohajonWarm.tintGreen,
              ),
              const SizedBox(width: 8),
              _MiniStat(
                label: outstanding > 0 ? l10n.t('due') : l10n.t('cleared'),
                value: money(outstanding),
                color: outstanding > 0
                    ? MohajonWarm.red
                    : MohajonWarm.green,
                background: outstanding > 0
                    ? MohajonWarm.tintRed
                    : MohajonWarm.tintGreen,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MohajonWarm.ink,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: MohajonWarm.goldBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      _launchPhone(context, vendor.phone);
                    },
                    icon: const Icon(Icons.call_rounded, size: 16),
                    label: Text(
                      l10n.t('call'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MohajonWarm.ink,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: MohajonWarm.goldBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      _launchEmail(context, vendor.email);
                    },
                    icon: const Icon(Icons.email_rounded, size: 16),
                    label: Text(
                      l10n.t('email'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _launchPhone(BuildContext context, String phone) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.tP('callNumber', {'n': phone}))),
    );
  }

  void _launchEmail(BuildContext context, String email) {
    final l10n = AppLocalizations.of(context);
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('noEmailAvailable'))),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.tP('emailAddress', {'n': email}))),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
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
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 14,
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
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: MohajonWarm.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: MohajonWarm.muted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
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
      .where((part) => part.isNotEmpty);
  if (parts.isEmpty) return 'VN';
  final value = parts.take(2).map((part) => part[0].toUpperCase()).join();
  return value.length == 1 ? '${value}N' : value;
}
