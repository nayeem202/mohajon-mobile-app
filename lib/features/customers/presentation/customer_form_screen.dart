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
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    final customer = widget.customer;
    if (customer != null) {
      _name.text = customer.name;
      _phone.text = customer.phone;
      _email.text = customer.email;
      _address.text = customer.address;
      _notes.text = customer.notes;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.customer != null;
    return withLoadingOverlay(
      Scaffold(
        appBar: AppBar(title: Text(isEditing ? 'Edit Client' : 'Add Client')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _FieldLabel(label: 'Full Name', required: true),
              const SizedBox(height: 8),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(hintText: 'e.g. Rahim Uddin'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              _FieldLabel(label: 'Phone', required: true),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  hintText: 'e.g. +880 1711-234567',
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              _FieldLabel(label: 'Email'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'e.g. rahim@example.com',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value.trim())) {
                    return 'Invalid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _FieldLabel(label: 'Address'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _address,
                maxLines: 1,
                decoration: const InputDecoration(
                  hintText: 'e.g. 12/A Mirpur Road, Dhaka',
                ),
              ),
              const SizedBox(height: 14),
              _FieldLabel(label: 'Notes'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notes,
                maxLines: 5,
                maxLength: 300,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Any special notes about this client...',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${_notes.text.length}/300',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.08),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.18),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Theme.of(context).colorScheme.secondary,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'New clients start with zero dues and zero visits. Their purchase history will update automatically as you add sales.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: isBusy ? null : _saveCustomer,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(isEditing ? 'Update Client' : 'Save Client'),
                ),
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
      await ref
          .read(customerServiceProvider)
          .save(
            customerId: widget.customer?.customerId,
            name: _name.text.trim(),
            phone: _phone.text.trim(),
            email: _email.text.trim(),
            address: _address.text.trim(),
            notes: _notes.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    });
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, this.required = false});

  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        children: [
          TextSpan(text: label),
          if (required)
            TextSpan(
              text: ' *',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }
}
