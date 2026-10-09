import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_error.dart';

import '../../../core/config/app_config.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';
import '../models/staff_model.dart';
import '../providers/staff_providers.dart';
import '../services/staff_api_service.dart';
import '../../subscription/services/paywall_gate.dart';
import 'delete_staff_dialog.dart';
import 'staff_form_screen.dart';

class StaffListScreen extends ConsumerStatefulWidget {
  const StaffListScreen({super.key});

  @override
  ConsumerState<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends ConsumerState<StaffListScreen> {
  final _searchController = TextEditingController();
  bool _showSearch = false;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? MohajonWarm.red : null,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openForm({StaffMember? staff}) async {
    if (!PaywallGate.hasBusiness(ref)) {
      await PaywallGate.showPaywallSheet(context, requiredTier: 'BUSINESS');
      return;
    }
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => StaffFormScreen(staff: staff)),
    );
    if (saved == true && mounted) {
      _showToast(
        staff == null
            ? _l10n.t('staffAdded')
            : _l10n.tP('staffUpdated', {'name': staff.name}),
      );
    }
  }

  Future<void> _toggleActive(StaffMember staff, bool active) async {
    if (staff.active == active) return;
    try {
      final api = ref.read(staffApiServiceProvider);
      await api.updateStaffStatus(userId: staff.id, active: active);
      ref.invalidate(staffListProvider);
      if (!mounted) return;
      _showToast(
        active
            ? _l10n.tP('staffActivated', {'name': staff.name})
            : _l10n.tP('staffDeactivated', {'name': staff.name}),
      );
    } catch (error) {
      if (!mounted) return;
      _showToast(
        friendlyErrorMessage(
          error,
          l10n: _l10n,
          fallback: _l10n.t('couldNotUpdateStatus'),
        ),
        isError: true,
      );
    }
  }

  Future<void> _confirmDelete(StaffMember staff) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) =>
          DeleteStaffDialog(onConfirm: () => Navigator.of(context).pop(true)),
    );
    if (confirmed != true || !mounted) return;
    try {
      final api = ref.read(staffApiServiceProvider);
      await api.deleteStaff(staff.id);
      ref.invalidate(staffListProvider);
      if (!mounted) return;
      _showToast(_l10n.tP('staffDeleted', {'name': staff.name}));
    } catch (error) {
      if (!mounted) return;
      _showToast(
        friendlyErrorMessage(
          error,
          l10n: _l10n,
          fallback: _l10n.t('couldNotUpdateStatus'),
        ),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(staffListProvider);
    final query = _searchController.text.toLowerCase();
    final staff = staffAsync.value ?? const <StaffMember>[];
    final filtered = query.isEmpty
        ? staff
        : staff
              .where(
                (s) =>
                    s.name.toLowerCase().contains(query) ||
                    s.role.toLowerCase().contains(query) ||
                    s.phone.contains(query),
              )
              .toList();
    final activeCount = staff.where((s) => s.active).length;
    final inactiveCount = staff.length - activeCount;
    final l10n = AppLocalizations.of(context);

    return Theme(
      data: MohajonWarm.theme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: MohajonWarm.pageGradient),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                  child: _Header(
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                ),
                if (_showSearch)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
                    child: Container(
                      decoration: BoxDecoration(
                        color: MohajonWarm.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: MohajonWarm.goldBorder),
                        boxShadow: [
                          BoxShadow(
                            color: MohajonWarm.ink.withValues(alpha: 0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: l10n.t('searchStaff'),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: MohajonWarm.muted,
                          ),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    color: MohajonWarm.muted,
                                  ),
                                ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (staff.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                    child: Text(
                      l10n.tP('staffSummary', {
                            'count': '${filtered.length}',
                            'total': '${staff.length}',
                            'active': '$activeCount',
                          }) +
                          (inactiveCount > 0
                              ? l10n.tP('staffSummaryInactive', {
                                  'inactive': '$inactiveCount',
                                })
                              : ''),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: MohajonWarm.muted,
                      ),
                    ),
                  ),
                Expanded(
                  child: staffAsync.isLoading && staff.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: MohajonWarm.primary,
                          ),
                        )
                      : staffAsync.hasError && staff.isEmpty
                      ? _errorState()
                      : staff.isEmpty
                      ? _emptyState()
                      : filtered.isEmpty
                      ? _emptySearchState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(18, 4, 18, 100),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _StaffCard(
                                key: ValueKey(item.id),
                                staff: item,
                                onEdit: () => _openForm(staff: item),
                                onDelete: () => _confirmDelete(item),
                                onToggleActive: (active) =>
                                    _toggleActive(item, active),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.small(
              heroTag: 'search',
              onPressed: () {
                setState(() => _showSearch = !_showSearch);
                if (!_showSearch) {
                  _searchController.clear();
                }
              },
              child: Icon(
                _showSearch ? Icons.search_off_rounded : Icons.search_rounded,
                size: 22,
              ),
            ),
            const SizedBox(height: 8),
            FloatingActionButton(
              heroTag: 'add',
              onPressed: () => _openForm(),
              child: const Icon(Icons.add_rounded, size: 26),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: MohajonWarm.goldBorder,
            ),
            const SizedBox(height: 16),
            Text(
              _l10n.t('couldNotLoadStaff'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: MohajonWarm.ink,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => ref.invalidate(staffListProvider),
              style: OutlinedButton.styleFrom(
                foregroundColor: MohajonWarm.ink,
                side: const BorderSide(color: MohajonWarm.goldBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(_l10n.t('retry')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptySearchState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 48,
              color: MohajonWarm.goldBorder,
            ),
            const SizedBox(height: 16),
            Text(
              _l10n.t('noStaffMatch'),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: MohajonWarm.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: MohajonWarm.goldBorder),
              ),
              child: const Icon(
                Icons.group_outlined,
                size: 28,
                color: MohajonWarm.goldText,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _l10n.t('noStaffMembersYet'),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: MohajonWarm.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _l10n.t('noStaffHint'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: MohajonWarm.muted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
            Icons.group_rounded,
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
                l10n.t('shopStaff'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: MohajonWarm.ink,
                ),
              ),
              Text(
                l10n.t('teamAndPermissions'),
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
    );
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({
    super.key,
    required this.staff,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  final StaffMember staff;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleActive;

  Widget _staffAvatar(StaffMember member) {
    const size = 44.0;
    final circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: member.avatarColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: member.avatarColor.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        member.initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
    if (member.photoUrl != null && member.photoUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          '${AppConfig.apiBaseUrl}${member.photoUrl}',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => circle,
        ),
      );
    }
    if (member.imagePath != null) {
      return ClipOval(
        child: Image.file(
          File(member.imagePath!),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => circle,
        ),
      );
    }
    return circle;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MohajonWarm.card,
      borderRadius: BorderRadius.circular(16),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _staffAvatar(staff),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        staff.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: MohajonWarm.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        staff.role,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: MohajonWarm.muted,
                        ),
                      ),
                      if (staff.phone.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          staff.phone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: MohajonWarm.muted,
                          ),
                        ),
                      ],
                      if (staff.menuCodes.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 5,
                          runSpacing: 5,
                          children: staff.menuCodes.take(3).map((code) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: MohajonWarm.tintYellow,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: MohajonWarm.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Text(
                                code,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: MohajonWarm.goldText,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _StatusSwitch(
                      active: staff.active,
                      onChanged: onToggleActive,
                    ),
                    const SizedBox(width: 4),
                    _ActionTile(icon: Icons.edit_rounded, onTap: onEdit),
                    const SizedBox(width: 4),
                    _ActionTile(
                      icon: Icons.delete_outline_rounded,
                      destructive: true,
                      onTap: onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusSwitch extends StatelessWidget {
  const _StatusSwitch({required this.active, required this.onChanged});

  final bool active;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 0.7,
      child: Switch(
        value: active,
        onChanged: onChanged,
        activeThumbColor: MohajonWarm.green,
        inactiveThumbColor: Colors.white,
        inactiveTrackColor: MohajonWarm.red.withValues(alpha: 0.45),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: destructive ? MohajonWarm.tintRed : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: MohajonWarm.goldBorder),
          ),
          child: Icon(
            icon,
            size: 15,
            color: destructive ? MohajonWarm.red : MohajonWarm.ink,
          ),
        ),
      ),
    );
  }
}
