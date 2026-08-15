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

/// Returns true when [granted] contains [required]. Owners/admins have full
/// access; a missing permission response is denied for staff by default.
bool hasMenuAccess(List<String>? granted, String? required, {bool isOwner = false}) {
  if (required == null) return true;
  if (isOwner) return true;
  // A missing permission response must fail closed for staff. Treating it as
  // full access made every menu visible while the request was loading or had
  // failed. Owners receive all menu codes from the backend as well.
  if (granted == null) return false;
  if (required == MenuCodes.stock) {
    return granted.contains(MenuCodes.stock) ||
        granted.contains(MenuCodes.products) ||
        granted.contains(MenuCodes.addProduct);
  }
  return granted.contains(required);
}
