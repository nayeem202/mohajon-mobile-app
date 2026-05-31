import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/customer.dart';
import '../../../core/widgets/async_action_state.dart';
import '../providers/customer_providers.dart';

class CustomerFormScreen extends ConsumerStatefulWidget {
  const CustomerFormScreen({super.key, this.customer});

  final Customer? customer;

  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen>
    with AsyncActionState<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();

  @override
  void initState() {
    super.initState();
    final customer = widget.customer;
    if (customer != null) {
      _name.text = customer.name;
      _phone.text = customer.phone;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.customer != null;
    return withLoadingOverlay(
      Scaffold(
        appBar: AppBar(title: Text(isEditing ? 'Edit customer' : 'Add customer')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: isBusy ? null : _saveCustomer,
                icon: const Icon(Icons.save_outlined),
                label: Text(isEditing ? 'Update' : 'Save'),
              ),
            ],
          ),
        ),
      ),
      label: 'Saving customer...',
    );
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;
    await runBusyAction(() async {
      await ref.read(customerServiceProvider).save(
        customerId: widget.customer?.customerId,
        name: _name.text.trim(),
        phone: _phone.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    });
  }
}
