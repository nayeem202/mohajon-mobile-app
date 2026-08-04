/// Menu codes used across the app. These match the seeded `menus` table in
/// the Haalkhata Java service and are configurable from the DB.
abstract final class MenuCodes {
  static const home = 'HOME';
  static const sales = 'SALES';
  static const stock = 'STOCK';
  static const clients = 'CLIENTS';
  static const products = 'PRODUCTS';
  static const addProduct = 'ADD_PRODUCT';
  static const addCustomer = 'ADD_CUSTOMER';
  static const vendors = 'VENDORS';
  static const expenses = 'EXPENSES';
  static const investors = 'INVESTORS';
  static const barcode = 'BARCODE';
  static const purchase = 'PURCHASE';
  static const due = 'DUE';
  static const investments = 'INVESTMENTS';
  static const reports = 'REPORTS';
  static const salesHistory = 'SALES_HISTORY';
  static const profile = 'PROFILE';
  static const staff = 'STAFF';
  static const settings = 'SETTINGS';
  static const security = 'SECURITY';
  static const privacy = 'PRIVACY';
}

/// Returns true when [granted] (nullable so a failed fetch falls back to
/// full access for offline safety) contains [required]. A null [required]
/// means the feature is always available.
bool hasMenuAccess(List<String>? granted, String? required) {
  if (required == null) return true;
  if (granted == null) return true;
  return granted.contains(required);
}
