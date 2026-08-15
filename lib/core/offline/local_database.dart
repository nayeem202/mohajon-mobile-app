import 'package:hive_flutter/hive_flutter.dart';

import '../../features/vendors/models/vendor.dart';
import '../../features/vendors/models/vendor_payment.dart';
import '../../features/vendors/models/vendor_purchase.dart';
import '../constants/app_constants.dart';
import '../models/app_user.dart';
import '../models/customer.dart';
import '../models/customer_ledger_entry.dart';
import '../../features/expenses/models/expense.dart';
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
        vendors = LocalCollection<Vendor>(
          Hive.box<Map>(HiveBoxes.vendors),
          Vendor.fromJson,
        ),
        vendorPurchases = LocalCollection<VendorPurchase>(
          Hive.box<Map>(HiveBoxes.vendorPurchases),
          VendorPurchase.fromJson,
        ),
        vendorPayments = LocalCollection<VendorPayment>(
          Hive.box<Map>(HiveBoxes.vendorPayments),
          VendorPayment.fromJson,
        ),
        expenses = LocalCollection<Expense>(
          Hive.box<Map>(HiveBoxes.expenses),
          Expense.fromJson,
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
  final LocalCollection<Vendor> vendors;
  final LocalCollection<VendorPurchase> vendorPurchases;
  final LocalCollection<VendorPayment> vendorPayments;
  final LocalCollection<Expense> expenses;
  final LocalCollection<AppUser> users;
  final Box<dynamic> settings;
  Box<Map> get notifications => Hive.box<Map>(HiveBoxes.notifications);

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
      vendors.clear(),
      vendorPurchases.clear(),
      vendorPayments.clear(),
      expenses.clear(),
      notifications.clear(),
      users.clear(),
    ]);
    final keys = settings.keys
        .where((key) => key.toString().startsWith('lastPulledAt.'))
        .toList();
    await settings.deleteAll(keys);
    await settings.delete('activeUserId');
    await settings.delete('activeShopId');
  }
}
