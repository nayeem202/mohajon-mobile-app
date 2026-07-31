import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_providers.dart';

class CustomerRulesSettingsScreen extends ConsumerStatefulWidget {
  const CustomerRulesSettingsScreen({super.key});

  @override
  ConsumerState<CustomerRulesSettingsScreen> createState() =>
      _CustomerRulesSettingsScreenState();
}

class _CustomerRulesSettingsScreenState
    extends ConsumerState<CustomerRulesSettingsScreen> {
  final _vipThresholdCtrl = TextEditingController();
  final _regularThresholdCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(localDatabaseProvider).settings;
    _vipThresholdCtrl.text =
        (settings.get('customerVipThreshold') as num? ?? 10000).toString();
    _regularThresholdCtrl.text =
        (settings.get('customerRegularThreshold') as num? ?? 1000).toString();
  }

  @override
  void dispose() {
    _vipThresholdCtrl.dispose();
    _regularThresholdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customer Rules')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B6F47).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.local_offer_rounded,
                          color: Color(0xFF8B6F47),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Auto-Tagging Rules',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: Color(0xFF101828),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Customers are automatically tagged based on their total lifetime spend.',
                    style: TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _FieldLabel(label: 'VIP Threshold (৳)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _vipThresholdCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: '10000',
                      prefixText: '৳ ',
                      helperText: 'Customers who spent at least this amount are tagged as VIP',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _FieldLabel(label: 'Regular Threshold (৳)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _regularThresholdCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: '1000',
                      prefixText: '৳ ',
                      helperText: 'Customers who spent at least this amount are tagged as Regular',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4E5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFFD29C)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: Color(0xFFF97316),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Tags are applied in real-time: customers spending ≥ VIP threshold get "VIP" tag, ≥ Regular threshold get "Regular" tag. VIP takes precedence.',
                            style: TextStyle(
                              color: Color(0xFFB45309),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _isSaving ? 'Saving...' : 'Save Rules',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final vip = double.tryParse(_vipThresholdCtrl.text.trim());
    final regular = double.tryParse(_regularThresholdCtrl.text.trim());
    if (vip == null || vip < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid VIP threshold')),
      );
      return;
    }
    if (regular == null || regular < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid Regular threshold')),
      );
      return;
    }
    final settings = ref.read(localDatabaseProvider).settings;
    setState(() => _isSaving = true);
    try {
      await settings.put('customerVipThreshold', vip);
      await settings.put('customerRegularThreshold', regular);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer rules saved successfully'),
          backgroundColor: Color(0xFF047857),
        ),
      );
    }
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        color: Color(0xFF101828),
        fontSize: 14,
      ),
    );
  }
}
