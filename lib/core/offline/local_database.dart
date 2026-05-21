import 'package:hive_flutter/hive_flutter.dart';

import '../constants/app_constants.dart';
import '../models/app_user.dart';
import '../models/customer.dart';
import '../models/customer_ledger_entry.dart';
import '../models/payment.dart';
import '../models/product.dart';
import '../models/purchase.dart';
import '../models/sale.dart';
import 'local_collection.dart';

class LocalDatabase {
  LocalDatabase()
      : products = LocalCollection<Product>(
          Hive.box<Map>(HiveBoxes.products),
          Product.fromJson,
        ),
        customers = LocalCollection<Customer>(
          Hive.box<Map>(HiveBoxes.customers),
          Customer.fromJson,
        ),
        sales = LocalCollection<Sale>(
          Hive.box<Map>(HiveBoxes.sales),
          Sale.fromJson,
        ),
        customerLedgerEntries = LocalCollection<CustomerLedgerEntry>(
          Hive.box<Map>(HiveBoxes.customerLedgerEntries),
          CustomerLedgerEntry.fromJson,
        ),
        payments = LocalCollection<Payment>(
          Hive.box<Map>(HiveBoxes.payments),
          Payment.fromJson,
        ),
        purchases = LocalCollection<Purchase>(
          Hive.box<Map>(HiveBoxes.purchases),
          Purchase.fromJson,
        ),
        suppliers = LocalCollection<Supplier>(
          Hive.box<Map>(HiveBoxes.suppliers),
          Supplier.fromJson,
        ),
        users = LocalCollection<AppUser>(
          Hive.box<Map>(HiveBoxes.users),
          AppUser.fromJson,
        ),
        settings = Hive.box<dynamic>(HiveBoxes.settings);

  final LocalCollection<Product> products;
  final LocalCollection<Customer> customers;
  final LocalCollection<Sale> sales;
  final LocalCollection<CustomerLedgerEntry> customerLedgerEntries;
  final LocalCollection<Payment> payments;
  final LocalCollection<Purchase> purchases;
  final LocalCollection<Supplier> suppliers;
  final LocalCollection<AppUser> users;
  final Box<dynamic> settings;

  Future<void> setActiveAccount({
    required String userId,
    required String shopId,
  }) async {
    final activeUserId = settings.get('activeUserId') as String?;
    final activeShopId = settings.get('activeShopId') as String?;
    if (activeUserId == userId && activeShopId == shopId) return;
    await clearBusinessData();
    await settings.put('activeUserId', userId);
    await settings.put('activeShopId', shopId);
  }

  Future<void> clearBusinessData() async {
    await Future.wait([
      products.clear(),
      customers.clear(),
      sales.clear(),
      customerLedgerEntries.clear(),
      payments.clear(),
      purchases.clear(),
      suppliers.clear(),
      users.clear(),
    ]);
    final keys = settings.keys
        .where((key) => key.toString().startsWith('firebaseLastPulledAt.'))
        .toList();
    await settings.deleteAll(keys);
  }
}
