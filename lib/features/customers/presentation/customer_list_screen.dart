import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../providers/customer_providers.dart';
import 'customer_detail_screen.dart';
import 'customer_form_screen.dart';

class CustomerListScreen extends ConsumerWidget {
  const CustomerListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final customers = ref.watch(customersProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('customers'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CustomerFormScreen())),
        icon: const Icon(Icons.person_add_alt),
        label: Text(l10n.t('addCustomer')),
      ),
      body: customers.when(
        data: (items) => items.isEmpty
            ? const EmptyState(message: 'Add customers to track due payments.', icon: Icons.people_alt_outlined)
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final customer = items[index];
                  final due = ref.watch(customerDueProvider(customer.customerId));
                  return Card(
                    child: ListTile(
                      title: Text(customer.name),
                      subtitle: Text(customer.phone),
                      trailing: Text(money(due), style: TextStyle(color: due > 0 ? Colors.red.shade700 : null)),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => CustomerDetailScreen(customer: customer)),
                      ),
                    ),
                  );
                },
              ),
        error: (error, _) => EmptyState(message: error.toString()),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
