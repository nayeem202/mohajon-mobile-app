import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/shop_profile.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/async_action_state.dart';
import '../providers/investment_providers.dart';

class InvestmentScreen extends ConsumerStatefulWidget {
  const InvestmentScreen({super.key});

  @override
  ConsumerState<InvestmentScreen> createState() => _InvestmentScreenState();
}

class _InvestmentScreenState extends ConsumerState<InvestmentScreen>
    with AsyncActionState<InvestmentScreen> {
  final List<_OwnerInput> _ownerInputs = [];
  bool _seeded = false;
  int _seedVersion = -1;

  @override
  void dispose() {
    for (final input in _ownerInputs) {
      input.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(investmentOverviewProvider);
    _seedOwners(overview.owners);

    final draftOwners = _draftOwners();
    final totalDraftInvestment = draftOwners.fold<double>(
      0,
      (sum, owner) => sum + owner.investmentAmount,
    );

    return withLoadingOverlay(
      Scaffold(
        appBar: AppBar(title: const Text('Investments')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _OverviewCard(overview: overview),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shop owners',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Add one or more owners. If there is one owner, that owner gets 100% of net profit. With multiple owners, profit is split by investment amount.',
                    ),
                    const SizedBox(height: 16),
                    for (var index = 0; index < _ownerInputs.length; index++) ...[
                      _OwnerEditorCard(
                        index: index,
                        totalOwners: _ownerInputs.length,
                        input: _ownerInputs[index],
                        onChanged: () => setState(() {}),
                        onRemove: _ownerInputs.length == 1
                            ? null
                            : () {
                                _removeOwner(index);
                              },
                      ),
                      const SizedBox(height: 12),
                    ],
                    OutlinedButton.icon(
                      onPressed: _confirmAddOwner,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add owner'),
                    ),
                    const SizedBox(height: 16),
                    _SharePreviewCard(
                      owners: draftOwners,
                      totalInvestment: totalDraftInvestment,
                      netProfit: overview.netProfit,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: isBusy ? null : _saveOwners,
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Save Owners'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      label: 'Saving owners...',
    );
  }

  void _seedOwners(List<ShopOwner> owners) {
    final version = owners.length * 1000000 +
        owners.fold<int>(
          0,
          (sum, owner) => sum + owner.name.hashCode + owner.investmentAmount.round(),
        );
    if (_seeded && _seedVersion == version) return;

    for (final input in _ownerInputs) {
      input.dispose();
    }
    _ownerInputs
      ..clear()
      ..addAll(owners.map(_OwnerInput.fromOwner));
    _seeded = true;
    _seedVersion = version;
  }

  List<ShopOwner> _draftOwners() => _ownerInputs
      .map(
        (input) => ShopOwner(
          ownerId: input.ownerId,
          name: input.nameController.text.trim(),
          investmentAmount:
              double.tryParse(input.investmentController.text.trim()) ?? 0,
        ),
      )
      .toList();

  void _addOwner() {
    setState(() {
      _ownerInputs.add(
        _OwnerInput(
          ownerId: '',
          nameController: TextEditingController(),
          investmentController: TextEditingController(text: '0'),
        ),
      );
    });
  }

  Future<void> _confirmAddOwner() async {
    final confirmed = await _confirmAction(
      title: 'Add owner',
      message: 'Do you want to add a new owner row?',
      confirmLabel: 'Add',
    );
    if (confirmed != true || !mounted) return;
    _addOwner();
  }

  Future<void> _removeOwner(int index) async {
    final confirmed = await _confirmAction(
      title: 'Delete owner',
      message: 'Do you want to remove this owner from the list?',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      final input = _ownerInputs.removeAt(index);
      input.dispose();
    });
  }

  Future<void> _saveOwners() async {
    FocusScope.of(context).unfocus();
    final isInsert = _seedVersion <= 0;
    final confirmed = await _confirmAction(
      title: isInsert ? 'Save owners' : 'Update owners',
      message: isInsert
          ? 'Do you want to save these owners and investment amounts?'
          : 'Do you want to update the owner and investment information?',
      confirmLabel: isInsert ? 'Save' : 'Update',
    );
    if (confirmed != true || !mounted) return;
    try {
      await runBusyAction(() async {
        await ref.read(investmentServiceProvider).saveOwners(_draftOwners());
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Owner investments updated')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<bool?> _confirmAction({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: colors.error,
                    foregroundColor: colors.onError,
                  )
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.overview});

  final InvestmentOverview overview;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: GridView(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 112,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _MiniMetric(
              label: 'Owners',
              value: '${overview.owners.length}',
              icon: Icons.groups_rounded,
              color: const Color(0xFF0F766E),
            ),
            _MiniMetric(
              label: 'Total investment',
              value: money(overview.totalInvestment),
              icon: Icons.account_balance_wallet_rounded,
              color: const Color(0xFF1D4ED8),
            ),
            _MiniMetric(
              label: 'Gross profit',
              value: money(overview.grossProfit),
              icon: Icons.trending_up_rounded,
              color: const Color(0xFF15803D),
            ),
            _MiniMetric(
              label: 'Gross loss',
              value: money(overview.grossLoss),
              icon: Icons.trending_down_rounded,
              color: const Color(0xFFB91C1C),
            ),
            _MiniMetric(
              label: 'Net profit',
              value: money(overview.netProfit),
              icon: Icons.pie_chart_rounded,
              color: const Color(0xFF7C3AED),
            ),
            _MiniMetric(
              label: 'Sales count',
              value: '${overview.totalSales}',
              icon: Icons.receipt_long_rounded,
              color: const Color(0xFF9A3412),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  height: 1.0,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}

class _OwnerEditorCard extends StatelessWidget {
  const _OwnerEditorCard({
    required this.index,
    required this.totalOwners,
    required this.input,
    required this.onChanged,
    this.onRemove,
  });

  final int index;
  final int totalOwners;
  final _OwnerInput input;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: input.nameController,
                  decoration: const InputDecoration(
                    labelText: 'Owner name',
                  ),
                  onChanged: (_) => onChanged(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: input.investmentController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Investment amount',
                    hintText: totalOwners == 1
                        ? 'Optional for single owner'
                        : 'Required for multiple owners',
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ],
            ),
          ),
          if (onRemove != null)
            Positioned(
              right: 0,
              top: 0,
              child: IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ),
        ],
      ),
    );
  }
}

class _SharePreviewCard extends StatelessWidget {
  const _SharePreviewCard({
    required this.owners,
    required this.totalInvestment,
    required this.netProfit,
  });

  final List<ShopOwner> owners;
  final double totalInvestment;
  final double netProfit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profit share preview',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          if (owners.length == 1)
            Text(
              '${owners.first.name.isEmpty ? 'Owner' : owners.first.name} receives 100% of ${money(netProfit)} net profit.',
            )
          else if (totalInvestment <= 0)
            Text(
              'Enter investment amounts to calculate profit ratio.',
              style: TextStyle(color: colors.error),
            )
          else
            for (final owner in owners)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${owner.name.isEmpty ? 'Owner' : owner.name}: ${((owner.investmentAmount / totalInvestment) * 100).toStringAsFixed(2)}% -> ${money(netProfit * (owner.investmentAmount / totalInvestment))}',
                ),
              ),
        ],
      ),
    );
  }
}

class _OwnerInput {
  _OwnerInput({
    required this.ownerId,
    required this.nameController,
    required this.investmentController,
  });

  factory _OwnerInput.fromOwner(ShopOwner owner) => _OwnerInput(
    ownerId: owner.ownerId,
    nameController: TextEditingController(text: owner.name),
    investmentController: TextEditingController(
      text: owner.investmentAmount == 0
          ? '0'
          : owner.investmentAmount.toString(),
    ),
  );

  final String ownerId;
  final TextEditingController nameController;
  final TextEditingController investmentController;

  void dispose() {
    nameController.dispose();
    investmentController.dispose();
  }
}
