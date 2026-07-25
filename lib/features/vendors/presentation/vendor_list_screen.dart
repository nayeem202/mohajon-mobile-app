import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../models/vendor.dart';
import '../providers/vendor_providers.dart';
import 'vendor_detail_screen.dart';
import 'vendor_form_sheet.dart';
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
    final vendorsAsync = ref.watch(vendorsProvider);
    final searchQuery = ref.watch(vendorSearchQueryProvider);
    final selectedCategory = ref.watch(vendorCategoryFilterProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: vendorsAsync.when(
          data: (items) {
            final filtered = ref.watch(filteredVendorsProvider);
            final totalSpent = items.fold<double>(0, (s, v) => s + v.totalSpent);
            final totalPending = items.fold<double>(0, (s, v) => s + v.pendingAmount);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                 _VendorsTopBar(onAddVendor: _openAddVendor),
                const SizedBox(height: 18),
                _VendorStats(
                  totalVendors: items.length,
                  totalSpent: totalSpent,
                  totalPending: totalPending,
                  onAddVendor: _openAddVendor,
                ),
                const SizedBox(height: 18),
                _SearchAndFilters(
                  controller: _searchController,
                  searchQuery: searchQuery,
                  selectedSort: _sort,
                  selectedCategory: selectedCategory,
                  onSearchChanged: (value) =>
                      ref.read(vendorSearchQueryProvider.notifier).state = value,
                  onClearSearch: () {
                    _searchController.clear();
                    ref.read(vendorSearchQueryProvider.notifier).state = '';
                  },
                  onSortChanged: (sort) {
                    setState(() => _sort = sort);
                    ref.read(vendorSortProvider.notifier).state = sort;
                  },
                  onCategoryChanged: (cat) =>
                      ref.read(vendorCategoryFilterProvider.notifier).state = cat,
                ),
                const SizedBox(height: 14),
                if (items.isEmpty)
                  const EmptyState(
                    message: 'Add vendors to manage purchases and payments.',
                    icon: Icons.store_outlined,
                  )
                else if (filtered.isEmpty)
                  const EmptyState(
                    message: 'No vendors match your search.',
                    icon: Icons.search_off_rounded,
                  )
                else
                  _VendorList(
                    vendors: filtered,
                    onVendorTap: (vendor) => _openVendorDetail(vendor),
                  ),
              ],
            );
          },
          error: (error, _) => EmptyState(message: error.toString()),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddVendor,
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  void _openAddVendor() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const VendorFormSheet(),
    );
  }

  void _openVendorDetail(Vendor vendor) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VendorDetailScreen(vendor: vendor),
      ),
    );
  }
}

class _VendorsTopBar extends StatelessWidget {
  const _VendorsTopBar({required this.onAddVendor});
  final VoidCallback onAddVendor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.store_rounded,
            color: Colors.white,
            size: 17,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Vendors',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: colors.onSurface,
            ),
          ),
        ),
        const NotificationBell(),
        const SizedBox(width: 14),
        const ShopAvatar(),
      ],
    );
  }
}

class _VendorStats extends StatelessWidget {
  const _VendorStats({
    required this.totalVendors,
    required this.totalSpent,
    required this.totalPending,
    required this.onAddVendor,
  });

  final int totalVendors;
  final double totalSpent;
  final double totalPending;
  final VoidCallback onAddVendor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: _VendorStatCard(
            label: 'Total\nVendors',
            value: '$totalVendors',
            subtext: 'Active suppliers',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _VendorStatCard(
            label: 'Total\nSpent',
            value: money(totalSpent),
            subtext: 'Across all vendors',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _VendorStatCard(
            label: 'Pending\nPayment',
            value: money(totalPending),
            subtext: 'Outstanding dues',
            valueColor: totalPending > 0 ? colors.error : colors.secondary,
          ),
        ),
      ],
    );
  }
}

class _VendorStatCard extends StatelessWidget {
  const _VendorStatCard({
    required this.label,
    required this.value,
    required this.subtext,
    this.valueColor,
  });

  final String label;
  final String value;
  final String subtext;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 138,
      padding: const EdgeInsets.fromLTRB(10, 11, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor ?? colors.onSurface,
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
              color: colors.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
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
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(14),
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
                      hintText: 'Search by company, person, phone...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: searchQuery.isEmpty
                          ? null
                          : IconButton(
                              onPressed: onClearSearch,
                              icon: const Icon(Icons.close_rounded),
                            ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
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
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: DropdownButton<VendorSort>(
                    value: selectedSort,
                    items: const [
                      DropdownMenuItem(value: VendorSort.newest, child: Text('Newest')),
                      DropdownMenuItem(value: VendorSort.oldest, child: Text('Oldest')),
                      DropdownMenuItem(value: VendorSort.highestDue, child: Text('Highest Due')),
                      DropdownMenuItem(value: VendorSort.lowestDue, child: Text('Lowest Due')),
                      DropdownMenuItem(value: VendorSort.mostOrders, child: Text('Most Orders')),
                      DropdownMenuItem(value: VendorSort.highestPurchase, child: Text('Highest Purchase')),
                      DropdownMenuItem(value: VendorSort.alphabetical, child: Text('A-Z')),
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
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _CategoryChip(
                    label: 'All',
                    selected: selectedCategory.isEmpty,
                    onTap: () => onCategoryChanged(''),
                  );
                }
                final cat = vendorCategories[index - 1];
                return _CategoryChip(
                  label: cat,
                  selected: selectedCategory == cat,
                  onTap: () => onCategoryChanged(selectedCategory == cat ? '' : cat),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colors.primary : Colors.white,
          border: Border.all(color: selected ? colors.primary : colors.outlineVariant),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : colors.onSurface,
            fontSize: 12,
            fontWeight: FontWeight.w800,
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
    final colors = Theme.of(context).colorScheme;
    final vendor = widget.vendor;
    final initials = _initials(vendor.companyName);
    final hasDue = vendor.pendingAmount > 0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: widget.onTap,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: colors.outlineVariant),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w900,
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
                                style: TextStyle(
                                  color: colors.onSurface,
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
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.error.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Due',
                                  style: TextStyle(
                                    color: Color(0xFFDC2626),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
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
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            _RatingStars(rating: vendor.rating),
                            const SizedBox(width: 6),
                            Text(
                              '${vendor.rating.toStringAsFixed(1)}',
                              style: const TextStyle(
                                color: Color(0xFFF59E0B),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
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
                        style: TextStyle(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hasDue ? 'Due ${money(vendor.pendingAmount)}' : 'Cleared',
                        style: TextStyle(
                          color: hasDue
                              ? colors.primary
                              : const Color(0xFF047857),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        vendor.lastPurchaseDate != null
                            ? _formatDate(vendor.lastPurchaseDate!)
                            : 'No purchases',
                        style: TextStyle(
                          color: colors.outline,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: colors.outline,
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

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }
}

class _VendorExpandedDetails extends ConsumerWidget {
  const _VendorExpandedDetails({required this.vendor});
  final Vendor vendor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outstanding = ref.watch(vendorOutstandingProvider(vendor.vendorId));
    final purchases = ref.watch(vendorPurchasesForVendorProvider(vendor.vendorId));
    final payments = ref.watch(vendorPaymentsForVendorProvider(vendor.vendorId));
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: colors.outlineVariant),
          right: BorderSide(color: colors.outlineVariant),
          bottom: BorderSide(color: colors.outlineVariant),
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(height: 1, color: colors.outlineVariant),
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
                label: 'Orders',
                value: '${purchases.length}',
                color: colors.primary,
              ),
              const SizedBox(width: 8),
              _MiniStat(
                label: 'Total Spent',
                value: money(vendor.totalSpent),
                color: colors.secondary,
              ),
              const SizedBox(width: 8),
              _MiniStat(
                label: outstanding > 0 ? 'Due' : 'Cleared',
                value: money(outstanding),
                color: outstanding > 0 ? colors.error : const Color(0xFF047857),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.secondary,
                    ),
                    onPressed: () {
                      _launchPhone(context, vendor.phone);
                    },
                    icon: const Icon(Icons.call_rounded, size: 16),
                    label: const Text('Call', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.primary,
                    ),
                    onPressed: () {
                      _launchEmail(context, vendor.email);
                    },
                    icon: const Icon(Icons.email_rounded, size: 16),
                    label: const Text('Email', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Call $phone')),
    );
  }

  void _launchEmail(BuildContext context, String email) {
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email address available')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Email $email')),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
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
                fontWeight: FontWeight.w600,
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
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colors.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: colors.onSurfaceVariant,
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

class _RatingStars extends StatelessWidget {
  const _RatingStars({required this.rating});
  final double rating;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fullStars = rating.floor();
    final hasHalf = rating - fullStars >= 0.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < fullStars) {
          return const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B));
        } else if (index == fullStars && hasHalf) {
          return const Icon(Icons.star_half_rounded, size: 14, color: Color(0xFFF59E0B));
        }
        return Icon(Icons.star_outline_rounded, size: 14, color: colors.outline);
      }),
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
