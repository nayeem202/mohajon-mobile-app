import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../providers/customer_providers.dart';
import 'customer_detail_screen.dart';
import 'customer_form_screen.dart';

class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final customers = ref.watch(customersProvider);
    final searchQuery = ref.watch(customerSearchQueryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('customers'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CustomerFormScreen())),
        icon: const Icon(Icons.person_add_alt),
        label: Text(l10n.t('addCustomer')),
      ),
      body: customers.when(
        data: (items) {
          final filteredItems = ref.watch(filteredCustomersProvider);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => ref
                      .read(customerSearchQueryProvider.notifier)
                      .state = value,
                  decoration: InputDecoration(
                    hintText: 'Search customers by name or phone',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: searchQuery.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              ref.read(customerSearchQueryProvider.notifier).state = '';
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? const EmptyState(
                        message: 'Add customers to track due payments.',
                        icon: Icons.people_alt_outlined,
                      )
                    : filteredItems.isEmpty
                    ? const EmptyState(
                        message: 'No customers match your search.',
                        icon: Icons.search_off_rounded,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final customer = filteredItems[index];
                          final due = ref.watch(customerDueProvider(customer.customerId));
                          return Card(
                            child: ListTile(
                              title: Text(customer.name),
                              subtitle: Text(customer.phone),
                              trailing: Text(
                                money(due),
                                style: TextStyle(
                                  color: due > 0 ? Colors.red.shade700 : null,
                                ),
                              ),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => CustomerDetailScreen(customer: customer),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        error: (error, _) => EmptyState(message: error.toString()),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
