import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../core/widgets/action_button.dart';
import '../../../core/widgets/async_action_state.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../core/widgets/shop_avatar.dart';
import '../models/investor.dart';
import '../providers/investor_providers.dart';
import '../providers/investor_service.dart';
import 'investor_detail_screen.dart';
import 'widgets/investor_card.dart';

class InvestorListScreen extends ConsumerStatefulWidget {
  const InvestorListScreen({super.key});

  @override
  ConsumerState<InvestorListScreen> createState() =>
      _InvestorListScreenState();
}

class _InvestorListScreenState extends ConsumerState<InvestorListScreen> {
  final _searchController = TextEditingController();
  bool _pnlExpanded = false;
  bool _showSearch = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final filtered = ref.watch(filteredInvestorsProvider);
    final query = ref.watch(investorSearchQueryProvider);
    final overview = ref.watch(investorsOverviewProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Investors',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: colors.onSurface,
          ),
        ),
        actions: [
          const NotificationBell(),
          const SizedBox(width: 4),
          const ShopAvatar(radius: 16, backgroundColor: Color(0xFFF97316), textColor: Colors.white),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF97316).withValues(alpha: 0.25),
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
                    Text('${overview.totalInvestors}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w900)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Net P&L',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Outstanding',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Total Investors',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SummaryBox(
                    label: 'Total Invested',
                    value: money(overview.totalInvestment),
                    color: const Color(0xFFF97316)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryBox(
                    label: 'Total Profit',
                    value: money(overview.totalProfit),
                    color: const Color(0xFF047857)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryBox(
                    label: 'Total Loss',
                    value: money(overview.totalLoss),
                    color: const Color(0xFFDC2626)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryBox(
                    label: 'Outstanding',
                    value: money(overview.totalOutstanding),
                    color: const Color(0xFF2563EB)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _pnlExpanded = !_pnlExpanded),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('Profit / Loss Sharing Methods',
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: Color(0xFF101828))),
                      ),
                      AnimatedRotation(
                        turns: _pnlExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.keyboard_arrow_up_rounded,
                            color: Color(0xFF667085)),
                      ),
                    ],
                  ),
                ),
                ClipRect(
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    heightFactor: _pnlExpanded ? 1 : 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF7ED),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: const Color(0xFFF97316)
                                            .withValues(alpha: 0.2)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('Proportional',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF9A3412),
                                              fontSize: 13)),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Profit automatically calculated according to contribution.',
                                        style: TextStyle(
                                            color: const Color(0xFF9A3412)
                                                .withValues(alpha: 0.7),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: const Color(0xFFF0ECE4)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('Fixed Rate',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF101828),
                                              fontSize: 13)),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Manual percentage regardless of contribution.',
                                        style: TextStyle(
                                            color: const Color(0xFF667085)
                                                .withValues(alpha: 0.7),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text('How Paid Out Is Calculated',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: Color(0xFF101828))),
                        const SizedBox(height: 10),
                        _StepRow(
                            number: '1',
                            label: 'Total Due',
                            desc: 'Investment + Profit'),
                        _StepRow(
                            number: '2',
                            label: 'Paid Out',
                            desc: 'Sum of payouts'),
                        _StepRow(
                            number: '3',
                            label: 'Outstanding',
                            desc: 'Total Due – Paid',
                            showDivider: false),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_showSearch) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 46,
              child: TextField(
                controller: _searchController,
                onChanged: (v) =>
                    ref.read(investorSearchQueryProvider.notifier).update(v),
                decoration: InputDecoration(
                  hintText: 'Search by name or phone...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            ref
                                .read(investorSearchQueryProvider.notifier)
                                .update('');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: Color(0xFFECE7DF)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: Color(0xFFECE7DF)),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (filtered.isEmpty)
            const EmptyState(
              message: 'No investors found. Add one to get started.',
              icon: Icons.people_outline_rounded,
            )
          else
            ...filtered.map(
              (inv) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InvestorCard(
                  investor: inv,
                  onTap: () => _openDetail(context, inv),
                ),
              ),
            ),
          ],
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
                ref.read(investorSearchQueryProvider.notifier).update('');
              }
            },
            backgroundColor: const Color(0xFFF97316),
            foregroundColor: Colors.white,
            child: Icon(_showSearch ? Icons.close : Icons.search_rounded),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'add',
            onPressed: () => _showAddDialog(context),
            backgroundColor: const Color(0xFFF97316),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.person_add_rounded, size: 28),
          ),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context, Investor investor) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            InvestorDetailScreen(investorId: investor.id),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _AddInvestorDialog(),
    );
  }
}

class _SummaryBox extends StatelessWidget {
  const _SummaryBox({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: color)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11,
                  color: color.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.label,
    required this.desc,
    this.showDivider = true,
  });

  final String number;
  final String label;
  final String desc;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(number,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF101828),
                        fontSize: 14)),
              ),
              Text(desc,
                  style: const TextStyle(
                      color: Color(0xFF525252),
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
      ],
    );
  }
}

class _AddInvestorDialog extends ConsumerStatefulWidget {
  const _AddInvestorDialog();

  @override
  ConsumerState<_AddInvestorDialog> createState() =>
      _AddInvestorDialogState();
}

class _AddInvestorDialogState extends ConsumerState<_AddInvestorDialog>
    with AsyncActionState<_AddInvestorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Investor'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Name *'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(labelText: 'Address'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ActionButton(
          onPressed: _save,
          isBusy: isBusy,
          label: 'Save',
          busyLabel: 'Saving...',
          expanded: false,
          height: 40,
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await runBusyAction(() async {
        await ref.read(investorServiceProvider).save(
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          notes: _notesCtrl.text.trim(),
        );
      });
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Investor added')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}
