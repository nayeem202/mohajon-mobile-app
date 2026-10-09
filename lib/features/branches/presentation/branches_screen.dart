import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/app_error.dart';
import '../../../core/utils/snackbar.dart';
import '../../staff/models/staff_model.dart';
import '../../staff/services/staff_api_service.dart';
import '../../subscription/services/paywall_gate.dart';
import '../models/branch.dart';
import '../providers/branch_providers.dart';

class BranchesScreen extends ConsumerWidget {
  const BranchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final branches = ref.watch(branchesProvider);
    final selected = ref.watch(currentBranchIdProvider);

    return Theme(
      data: MohajonWarm.theme(Theme.of(context), locale: locale),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(l10n.t('branches')),
          actions: [
            _BranchCount(value: branches),
            const SizedBox(width: 12),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _create(context, ref),
          icon: const Icon(Icons.add_business_rounded),
          label: Text(l10n.t('addBranch')),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: MohajonWarm.pageGradient),
          child: branches.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: MohajonWarm.ink),
            ),
            error: (error, _) => _BranchLoadError(
              message: friendlyErrorMessage(
                error,
                l10n: l10n,
                fallback: l10n.t('branchLoadFailed'),
              ),
              onRetry: () => ref.invalidate(branchesProvider),
            ),
            data: (items) {
              String? activeId = selected;
              if (activeId == null ||
                  !items.any((item) => item.branchId == activeId)) {
                for (final item in items) {
                  if (item.isDefault) {
                    activeId = item.branchId;
                    break;
                  }
                }
              }
              return RefreshIndicator(
                color: MohajonWarm.ink,
                onRefresh: () async {
                  ref.invalidate(branchesProvider);
                  await ref.read(branchesProvider.future);
                },
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 112),
                  itemCount: items.isEmpty ? 2 : items.length + 1,
                  separatorBuilder: (_, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _BranchHero(
                        branchCount: items.length,
                        subtitle: l10n.t('branchesSubtitle'),
                      );
                    }
                    if (items.isEmpty) return _BranchEmptyState(l10n: l10n);
                    final branch = items[index - 1];
                    return _BranchCard(
                      branch: branch,
                      selected: activeId == branch.branchId,
                      onTap: branch.isActive
                          ? () async {
                              await ref
                                  .read(branchServiceProvider)
                                  .select(branch);
                            }
                          : null,
                      onAssignStaff: () => _assignStaff(context, ref, branch),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _assignStaff(
    BuildContext context,
    WidgetRef ref,
    Branch branch,
  ) async {
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Theme(
        data: MohajonWarm.theme(
          Theme.of(context),
          locale: Localizations.localeOf(context),
        ),
        child: AlertDialog(
          title: Text(
            '${l10n.t('assignStaff')} — ${_displayName(branch, l10n)}',
          ),
          content: SizedBox(
            width: 420,
            height: 360,
            child: FutureBuilder<List<StaffMember>>(
              future: ref.read(staffApiServiceProvider).fetchStaff(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      friendlyErrorMessage(snapshot.error!, l10n: l10n),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                final staff = (snapshot.data ?? const <StaffMember>[])
                    .where((member) => member.active)
                    .toList();
                if (staff.isEmpty) {
                  return Center(child: Text(l10n.t('noStaffMembersYet')));
                }
                return ListView.separated(
                  itemCount: staff.length,
                  separatorBuilder: (_, index) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final member = staff[index];
                    return ListTile(
                      leading: CircleAvatar(child: Text(member.initials)),
                      title: Text(member.name),
                      subtitle: Text(member.role),
                      trailing: FilledButton.tonal(
                        onPressed: () async {
                          try {
                            await ref
                                .read(staffApiServiceProvider)
                                .assignToBranch(
                                  branchId: branch.branchId,
                                  userId: member.id,
                                );
                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop();
                            if (context.mounted) {
                              showAppSnackBar(context, l10n.t('staffAssigned'));
                            }
                          } catch (error) {
                            if (context.mounted) {
                              showAppSnackBar(
                                context,
                                friendlyErrorMessage(error, l10n: l10n),
                                isError: true,
                              );
                            }
                          }
                        },
                        child: Text(l10n.t('assign')),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.t('close')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    if (!PaywallGate.hasBusiness(ref)) {
      await PaywallGate.showPaywallSheet(context, requiredTier: 'BUSINESS');
      return;
    }
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateBranchSheet(),
    );
    if (result == true) {
      ref.invalidate(branchesProvider);
      if (context.mounted) {
        showAppSnackBar(context, AppLocalizations.of(context).t('branchAdded'));
      }
    }
  }
}

class _BranchCount extends StatelessWidget {
  const _BranchCount({required this.value});

  final AsyncValue<List<Branch>> value;

  @override
  Widget build(BuildContext context) {
    final label = value.when(
      data: (items) => '${items.length}',
      loading: () => '…',
      error: (_, _) => '—',
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: MohajonWarm.ink.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }
}

class _BranchHero extends StatelessWidget {
  const _BranchHero({required this.branchCount, required this.subtitle});

  final int branchCount;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MohajonWarm.ink,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: MohajonWarm.primary,
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.account_tree_rounded,
              color: MohajonWarm.ink,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFF8F2DD),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              Text(
                '$branchCount',
                style: const TextStyle(
                  color: MohajonWarm.primary,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                AppLocalizations.of(context).t('branchLocations'),
                style: const TextStyle(
                  color: Color(0xFFB9B5A4),
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BranchEmptyState extends StatelessWidget {
  const _BranchEmptyState({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: MohajonWarm.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: MohajonWarm.goldBorder),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.store_mall_directory_outlined,
            size: 42,
            color: MohajonWarm.goldText,
          ),
          const SizedBox(height: 12),
          Text(l10n.t('noBranches'), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _BranchLoadError extends StatelessWidget {
  const _BranchLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: MohajonWarm.orange,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(AppLocalizations.of(context).t('retry')),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateBranchSheet extends ConsumerStatefulWidget {
  const _CreateBranchSheet();

  @override
  ConsumerState<_CreateBranchSheet> createState() => _CreateBranchSheetState();
}

class _CreateBranchSheetState extends ConsumerState<_CreateBranchSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save(AppLocalizations l10n) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(branchServiceProvider)
          .create(name: _nameController.text, address: _addressController.text);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        showAppSnackBar(
          context,
          friendlyErrorMessage(error, l10n: l10n),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Theme(
      data: MohajonWarm.theme(Theme.of(context), locale: locale),
      child: PopScope(
        canPop: !_saving,
        child: Padding(
          padding: EdgeInsets.only(bottom: keyboard),
          child: SafeArea(
            top: false,
            child: Material(
              color: MohajonWarm.card,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: MohajonWarm.goldBorder,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: MohajonWarm.tintYellow,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(
                              Icons.add_business_rounded,
                              color: MohajonWarm.goldText,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.t('addBranch'),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.t('branchFormIntro'),
                        style: const TextStyle(
                          color: MohajonWarm.muted,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 22),
                      TextFormField(
                        controller: _nameController,
                        autofocus: true,
                        textInputAction: TextInputAction.next,
                        maxLength: 150,
                        decoration: InputDecoration(
                          labelText: l10n.t('branchName'),
                          hintText: l10n.t('branchNameHint'),
                          prefixIcon: const Icon(Icons.storefront_outlined),
                          counterText: '',
                        ),
                        validator: (value) {
                          final name = value?.trim() ?? '';
                          if (name.isEmpty) {
                            return l10n.t('branchNameRequired');
                          }
                          if (name.length > 150) {
                            return l10n.t('branchNameTooLong');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _addressController,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _saving ? null : _save(l10n),
                        maxLength: 255,
                        minLines: 2,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: l10n.t('branchAddress'),
                          hintText: l10n.t('branchAddressHint'),
                          alignLabelWithHint: true,
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 30),
                            child: Icon(Icons.location_on_outlined),
                          ),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : () => _save(l10n),
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: MohajonWarm.ink,
                                  ),
                                )
                              : const Icon(Icons.check_rounded),
                          label: Text(l10n.t('branchSave')),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: MohajonWarm.primary,
                            foregroundColor: MohajonWarm.ink,
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BranchCard extends StatelessWidget {
  const _BranchCard({
    required this.branch,
    required this.selected,
    required this.onTap,
    required this.onAssignStaff,
  });

  final Branch branch;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback onAssignStaff;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final location = branch.address.isNotEmpty ? branch.address : branch.phone;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: MohajonWarm.card.withValues(alpha: .96),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? MohajonWarm.primary : MohajonWarm.goldBorder,
              width: selected ? 1.8 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 16,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: selected
                        ? [MohajonWarm.tintGreen, const Color(0xFFD7F0D7)]
                        : [MohajonWarm.tintYellow, const Color(0xFFFFECA2)],
                  ),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  branch.isDefault
                      ? Icons.home_work_rounded
                      : Icons.storefront_rounded,
                  color: selected ? MohajonWarm.green : MohajonWarm.goldText,
                  size: 27,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayName(branch, l10n),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: MohajonWarm.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 15,
                          color: selected
                              ? MohajonWarm.green
                              : MohajonWarm.muted,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          selected
                              ? l10n.t('activeBranch')
                              : l10n.t('switchBranch'),
                          style: TextStyle(
                            color: selected
                                ? MohajonWarm.green
                                : MohajonWarm.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                tooltip: l10n.t('assignStaff'),
                onPressed: onAssignStaff,
                icon: const Icon(Icons.manage_accounts_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: MohajonWarm.tintYellow,
                  foregroundColor: MohajonWarm.goldText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _displayName(Branch branch, AppLocalizations l10n) {
  if (branch.isDefault && branch.name.trim().toLowerCase() == 'main branch') {
    return l10n.t('mainBranch');
  }
  return branch.name;
}
