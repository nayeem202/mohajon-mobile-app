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
import '../models/stock_adjustment.dart';
import '../models/audit_event.dart';
import '../models/product_batch.dart';
import '../models/sale_return.dart';
import '../models/purchase.dart';
import '../../features/purchases/models/purchase_order.dart';
import '../../features/purchases/models/supplier_return.dart';
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
  final LocalCollection<PurchaseOrder> purchaseOrders =
      LocalCollection<PurchaseOrder>(
        Hive.box<Map>(HiveBoxes.purchaseOrders),
        PurchaseOrder.fromJson,
      );
  final LocalCollection<StockAdjustment> stockAdjustments =
      LocalCollection<StockAdjustment>(
        Hive.box<Map>(HiveBoxes.stockAdjustments),
        StockAdjustment.fromJson,
      );
  final LocalCollection<SupplierReturn> supplierReturns =
      LocalCollection<SupplierReturn>(
        Hive.box<Map>(HiveBoxes.supplierReturns),
        SupplierReturn.fromJson,
      );
  final LocalCollection<AuditEvent> auditEvents = LocalCollection<AuditEvent>(
    Hive.box<Map>(HiveBoxes.auditEvents),
    AuditEvent.fromJson,
  );
  final LocalCollection<ProductBatch> productBatches =
      LocalCollection<ProductBatch>(
        Hive.box<Map>(HiveBoxes.productBatches),
        ProductBatch.fromJson,
      );
  final LocalCollection<SaleReturn> saleReturns = LocalCollection<SaleReturn>(
    Hive.box<Map>(HiveBoxes.saleReturns),
    SaleReturn.fromJson,
  );
  final LocalCollection<Supplier> suppliers;
  final LocalCollection<Vendor> vendors;
  final LocalCollection<VendorPurchase> vendorPurchases;
  final LocalCollection<VendorPayment> vendorPayments;
  final LocalCollection<Expense> expenses;
  final LocalCollection<AppUser> users;
  final Box<dynamic> settings;
  Box<Map> get notifications => Hive.box<Map>(HiveBoxes.notifications);

  Future<int> restoreBackup(Map<String, dynamic> backup, String shopId) async {
    if (backup['app'] != 'Mohajon' || backup['exportedAt'] is! String) {
      throw const FormatException('Invalid Mohajon backup file.');
    }
    final collections = backup['collections'] is Map
        ? Map<String, dynamic>.from(backup['collections'] as Map)
        : backup;
    final targets = <String, LocalCollection<dynamic>>{
      'products': products,
      'customers': customers,
      'sales': sales,
      'customerLedgerEntries': customerLedgerEntries,
      'payments': payments,
      'purchases': purchases,
      'suppliers': suppliers,
      'vendors': vendors,
      'vendorPurchases': vendorPurchases,
      'vendorPayments': vendorPayments,
      'expenses': expenses,
      'users': users,
      'purchaseOrders': purchaseOrders,
      'stockAdjustments': stockAdjustments,
      'supplierReturns': supplierReturns,
      'auditEvents': auditEvents,
      'productBatches': productBatches,
      'saleReturns': saleReturns,
    };
    var restored = 0;
    for (final entry in targets.entries) {
      final rows = collections[entry.key];
      if (rows is! List) continue;
      for (final raw in rows) {
        if (raw is! Map) throw FormatException('Invalid ${entry.key} record.');
        final json = Map<String, dynamic>.from(raw);
        final id =
            (json['id'] ??
                    json[entry.key == 'productBatches'
                        ? 'batchId'
                        : '${entry.key.substring(0, entry.key.length - (entry.key.endsWith('s') ? 1 : 0))}Id'])
                ?.toString();
        if (id == null || id.isEmpty) {
          throw FormatException('Missing id in ${entry.key}.');
        }
        json['shopId'] = shopId;
        await entry.value.putRawPending(shopId, id, json);
        restored++;
      }
    }
    return restored;
  }

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
    // A branch selection belongs to exactly one shop. Never carry it into a
    // different account; the server rejects cross-shop branch headers.
    await settings.delete('activeBranchId');
    await settings.delete('activeBranchShopId');
  }

  Future<void> clearBusinessData() async {
    await Future.wait([
      products.clear(),
      customers.clear(),
      sales.clear(),
      customerLedgerEntries.clear(),
      payments.clear(),
      purchases.clear(),
      purchaseOrders.clear(),
      stockAdjustments.clear(),
      supplierReturns.clear(),
      auditEvents.clear(),
      productBatches.clear(),
      saleReturns.clear(),
      suppliers.clear(),
      vendors.clear(),
      vendorPurchases.clear(),
      vendorPayments.clear(),
      expenses.clear(),
      users.clear(),
    ]);
    final keys = settings.keys
        .where(
          (key) =>
              key.toString().startsWith('lastPulledAt.') ||
              key.toString().startsWith('accounting.cache.') ||
              key.toString().startsWith('accounting.outbox.'),
        )
        .toList();
    await settings.deleteAll(keys);
    await settings.delete('activeUserId');
    await settings.delete('activeShopId');
    await settings.delete('activeBranchId');
    await settings.delete('activeBranchShopId');
  }
}
