import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../models/branch.dart';
import '../providers/branch_providers.dart';
import '../../staff/models/staff_model.dart';
import '../../staff/services/staff_api_service.dart';

class BranchesScreen extends ConsumerWidget {
  const BranchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final branches = ref.watch(branchesProvider);
    final selected = ref.watch(currentBranchIdProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('branches'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add_business_rounded),
        label: Text(l10n.t('addBranch')),
      ),
      body: branches.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (items) => items.isEmpty
            ? Center(child: Text(l10n.t('noBranches')))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, index) => const SizedBox(height: 10),
                itemBuilder: (_, index) => _BranchCard(
                  branch: items[index],
                  selected: selected == items[index].branchId,
                  onTap: () => ref.read(branchServiceProvider).select(items[index]),
                  onAssignStaff: () => _assignStaff(context, ref, items[index]),
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
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${AppLocalizations.of(context).t('assignStaff')} — ${branch.name}'),
        content: SizedBox(
          width: 420,
          height: 360,
          child: FutureBuilder<List<StaffMember>>(
            future: ref.read(staffApiServiceProvider).fetchStaff(),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
              final staff = (snapshot.data ?? const <StaffMember>[])
                  .where((member) => member.active)
                  .toList();
              if (staff.isEmpty) {
                return Center(child: Text(AppLocalizations.of(context).t('noStaffMembersYet')));
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
                          await ref.read(staffApiServiceProvider).assignToBranch(
                                branchId: branch.branchId,
                                userId: member.id,
                              );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(AppLocalizations.of(context).t('staffAssigned'))),
                            );
                          }
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$error')),
                            );
                          }
                        }
                      },
                      child: Text(AppLocalizations.of(context).t('assign')),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(AppLocalizations.of(context).t('close'))),
        ],
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final address = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context).t('addBranch')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: InputDecoration(labelText: AppLocalizations.of(context).t('branchName'))),
            TextField(controller: address, decoration: InputDecoration(labelText: AppLocalizations.of(context).t('branchAddress'))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(AppLocalizations.of(context).t('cancel'))),
          FilledButton(onPressed: () async {
            try {
              await ref.read(branchServiceProvider).create(name: name.text, address: address.text);
              if (dialogContext.mounted) Navigator.pop(dialogContext, true);
            } catch (error) {
              if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('$error')));
            }
          }, child: Text(AppLocalizations.of(context).t('save'))),
        ],
      ),
    );
    name.dispose();
    address.dispose();
    if (result == true) ref.invalidate(branchesProvider);
  }
}

class _BranchCard extends StatelessWidget {
  const _BranchCard({required this.branch, required this.selected, required this.onTap, required this.onAssignStaff});
  final Branch branch;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onAssignStaff;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          onTap: branch.isActive ? onTap : null,
          leading: CircleAvatar(
            backgroundColor: selected ? MohajonWarm.tintGreen : MohajonWarm.tintYellow,
            child: Icon(Icons.storefront_rounded, color: selected ? MohajonWarm.green : MohajonWarm.goldText),
          ),
          title: Text(branch.name, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(branch.address.isEmpty ? branch.phone : branch.address),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: AppLocalizations.of(context).t('assignStaff'),
                onPressed: onAssignStaff,
                icon: const Icon(Icons.manage_accounts_rounded),
              ),
              if (selected) const Icon(Icons.check_circle_rounded, color: MohajonWarm.green),
            ],
          ),
        ),
      );
}
