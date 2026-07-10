import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/models/shop_profile.dart';
import '../../../core/utils/money.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../../investments/providers/investment_providers.dart';
import 'account_security_screen.dart';
import 'shop_profile_screen.dart';
import '../providers/shop_profile_providers.dart';

class ShopProfileOverviewScreen extends ConsumerStatefulWidget {
  const ShopProfileOverviewScreen({super.key});

  @override
  ConsumerState<ShopProfileOverviewScreen> createState() =>
      _ShopProfileOverviewScreenState();
}

class _ShopProfileOverviewScreenState
    extends ConsumerState<ShopProfileOverviewScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(shopProfileProvider);
    final profile = profileAsync.value;
    final summary = ref.watch(dashboardProvider);
    final investment = ref.watch(investmentOverviewProvider);
    final User? user = ref.watch(authStateProvider).value;
    final shopName = _shopName(profile);
    final ownerName = _ownerName(user);
    final ownerEmail = user?.email?.trim().isNotEmpty == true
        ? user!.email!.trim()
        : 'karim@hishabbondhu.com';

    final monthlySales = summary.monthlySales[DateTime.now().month - 1];
    final grossMargin = (investment.grossProfit + investment.grossLoss) <= 0
        ? 0.0
        : (investment.grossProfit /
                  (investment.grossProfit + investment.grossLoss)) *
              100;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5EF),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _TopBar(shopName: 'Shop Profile'),
            if (profileAsync.isLoading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(minHeight: 2),
            ],
            const SizedBox(height: 16),
            _HeroCard(
              initials: _initials(shopName),
              title: shopName,
              subtitle: 'Your trusted neighborhood shop',
              chipLabel: _businessType(profile),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Monthly Sales',
                    value: money(monthlySales),
                    icon: Icons.storefront_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricCard(
                    label: 'Gross Margin',
                    value: '${grossMargin.toStringAsFixed(0)}%',
                    icon: Icons.trending_up_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricCard(
                    label: 'Dues',
                    value: money(summary.totalDue),
                    icon: Icons.receipt_long_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _TabButton(
                    label: 'Shop Info',
                    icon: Icons.store_rounded,
                    selected: _tabIndex == 0,
                    onTap: () => setState(() => _tabIndex = 0),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TabButton(
                    label: 'Owner Info',
                    icon: Icons.person_outline_rounded,
                    selected: _tabIndex == 1,
                    onTap: () => setState(() => _tabIndex = 1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_tabIndex == 0) ...[
              _SectionHeaderBar(
                title: 'Shop Details',
                editLabel: 'Edit',
                onEdit: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ShopProfileScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Address',
                titleIcon: Icons.location_on_outlined,
                child: _ShadedText(
                  text: _multiLineOrFallback(
                    profile?.location,
                    'House 42, Road 7, Block C\nDhaka 1212\nDhaka, Bangladesh',
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'Business Hours',
                titleIcon: Icons.access_time_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '08:00 AM - 10:00 PM',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF101828),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Closed on Friday',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'Details',
                titleIcon: Icons.info_outline_rounded,
                child: Column(
                  children: [
                    _DetailRow(
                      icon: Icons.store_rounded,
                      label: 'Business Type',
                      value: _businessType(profile),
                    ),
                    _DetailRow(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: _fallback(profile?.phoneNumber, '+880 1712-345678'),
                    ),
                    _DetailRow(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: ownerEmail,
                    ),
                    _DetailRow(
                      icon: Icons.language_rounded,
                      label: 'Website',
                      value: 'www.hishabbondhu.com',
                    ),
                    _DetailRow(
                      icon: Icons.calendar_month_outlined,
                      label: 'Established',
                      value: profile?.createdAt == null
                          ? '2019'
                          : profile!.createdAt!.year.toString(),
                    ),
                    _DetailRow(
                      icon: Icons.badge_outlined,
                      label: 'Tax ID',
                      value: 'TAX-2024-56789',
                    ),
                    _DetailRow(
                      icon: Icons.description_outlined,
                      label: 'TIN',
                      value: '123456789012',
                    ),
                    _DetailRow(
                      icon: Icons.receipt_outlined,
                      label: 'Trade License',
                      value: 'TRADE-DHK-2020-0042',
                    ),
                    _DetailRow(
                      icon: Icons.groups_outlined,
                      label: 'Employees',
                      value: '8',
                    ),
                    _DetailRow(
                      icon: Icons.square_foot_outlined,
                      label: 'Floor Area',
                      value: '850 sq ft',
                      showDivider: false,
                    ),
                  ],
                ),
              ),
            ] else ...[
              _SectionHeaderBar(
                title: 'Owner Info',
                editLabel: 'Edit',
                onEdit: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AccountSecurityScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _OwnerHeroCard(
                initials: _initials(ownerName),
                name: ownerName,
                role: 'Owner & Manager',
                since: 'Since ${profile?.createdAt?.year ?? 2019}',
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _ContactCard(
                      color: const Color(0xFFFDF1DF),
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: _fallback(profile?.phoneNumber, '+880 1712-345678'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ContactCard(
                      color: const Color(0xFFE4F6F1),
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: ownerEmail,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'Personal Information',
                titleIcon: Icons.person_2_outlined,
                child: Column(
                  children: [
                    _DetailRow(
                      icon: Icons.cake_outlined,
                      label: 'Date of Birth',
                      value: '1985-03-15',
                    ),
                    _DetailRow(
                      icon: Icons.badge_outlined,
                      label: 'NID Number',
                      value: '1234567890',
                    ),
                    _DetailRow(
                      icon: Icons.store_mall_directory_outlined,
                      label: 'Business Role',
                      value: 'Owner & Manager',
                    ),
                    _DetailRow(
                      icon: Icons.calendar_month_outlined,
                      label: 'Joined',
                      value: '${profile?.createdAt?.year ?? 2019}',
                      showDivider: false,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _shopName(ShopProfile? profile) {
    final value = profile?.shopName.trim();
    if (value != null && value.isNotEmpty) return value;
    return 'Haalkhata Store';
  }

  String _ownerName(User? user) {
    final displayName = user?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    return 'Karim Ahmed';
  }

  String _businessType(ShopProfile? profile) {
    final location = profile?.location.trim();
    if (location != null && location.isNotEmpty) return 'Retail Grocery';
    return 'Retail Grocery';
  }

  String _fallback(String? value, String fallback) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? fallback : trimmed;
  }

  String _multiLineOrFallback(String? value, String fallback) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? fallback : trimmed;
  }

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'KA';
    if (parts.length == 1) {
      final text = parts.first;
      return text.substring(0, text.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.shopName});

  final String shopName;

  @override
  Widget build(BuildContext context) {
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
            shopName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF101828),
            ),
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(Icons.notifications_none_rounded, color: Colors.grey.shade800),
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFD6F2EA),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            'KA',
            style: TextStyle(
              color: Color(0xFF0F766E),
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.initials,
    required this.title,
    required this.subtitle,
    required this.chipLabel,
  });

  final String initials;
  final String title;
  final String subtitle;
  final String chipLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF177D78),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF7FBEB8),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: Color(0xFF0B3A3A),
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
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
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    chipLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
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
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE8E4DB)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F1EB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: const Color(0xFF0F766E)),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF667085),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF101828),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeaderBar extends StatelessWidget {
  const _SectionHeaderBar({
    required this.title,
    required this.editLabel,
    required this.onEdit,
  });

  final String title;
  final String editLabel;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF101828),
            ),
          ),
        ),
        TextButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: Text(editLabel),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFF97316),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : const Color(0xFFF3EEE4),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? const Color(0xFFE8E4DB) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? const Color(0xFF101828)
                    : const Color(0xFF667085),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? const Color(0xFF101828)
                      : const Color(0xFF667085),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.titleIcon,
    required this.child,
  });

  final String title;
  final IconData titleIcon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE8E4DB)),
        borderRadius: BorderRadius.circular(16),
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
                  color: const Color(0xFFF4F1EB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(titleIcon, size: 17, color: const Color(0xFF8A5A11)),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF101828),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ShadedText extends StatelessWidget {
  const _ShadedText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F4EE),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          height: 1.6,
          color: Color(0xFF101828),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F3EE),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 15, color: const Color(0xFF667085)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        color: Color(0xFF101828),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, color: Color(0xFFF0ECE4)),
      ],
    );
  }
}

class _OwnerHeroCard extends StatelessWidget {
  const _OwnerHeroCard({
    required this.initials,
    required this.name,
    required this.role,
    required this.since,
  });

  final String initials;
  final String name;
  final String role;
  final String since;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE8E4DB)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFD6F2EA),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: Color(0xFF0F766E),
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
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
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF101828),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  role,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  since,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 13,
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

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.color,
    required this.icon,
    required this.label,
    required this.value,
  });

  final Color color;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0F766E)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF101828),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
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
