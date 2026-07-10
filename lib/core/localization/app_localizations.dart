import 'package:flutter/widgets.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('en'), Locale('bn')];

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const _values = <String, Map<String, String>>{
    'en': {
      'appName': 'Haalkhata',
      'dashboard': 'Dashboard',
      'home': 'Home',
      'menu': 'Menu',
      'more': 'Menu',
      'sales': 'Sales',
      'pos': 'POS',
      'stock': 'Stock',
      'customer': 'Customer',
      'customers': 'Customers',
      'clients': 'Clients',
      'due': 'Due',
      'products': 'Products',
      'purchase': 'Purchase',
      'investments': 'Invest',
      'settings': 'Settings',
      'todaySales': 'Today sales',
      'totalDue': 'Total due',
      'customersDue': 'Customers due',
      'topSelling': 'Top selling products',
      'lowStock': 'Low stock products',
      'monthlySummary': 'Monthly summary',
      'addProduct': 'Add product',
      'addCustomer': 'Add customer',
      'addPayment': 'Add payment',
      'ledger': 'Ledger',
      'paid': 'Paid',
      'partial': 'Partial',
      'cash': 'Cash',
      'bkash': 'bKash',
      'nagad': 'Nagad',
      'language': 'Language',
      'english': 'English',
      'bangla': 'Bangla',
      'offlineReady': 'Offline ready',
      'syncNow': 'Sync now',
      'owner': 'Owner',
      'staff': 'Staff',
      'login': 'Phone login',
      'sectionOperations': 'Operations',
      'sectionFinance': 'Finance',
      'sectionApp': 'App',
      'productsDesc': 'Stock, pricing, and barcodes',
      'customersDesc': 'Profiles, due, and ledger',
      'vendors': 'Vendors',
      'vendorsDesc': 'Purchases and supplier stock',
      'generateReceipt': 'Checkout',
      'receiptsDesc': 'Create customer receipts',
      'duesDesc': 'Customer balances and payments',
      'investmentsDesc': 'Owners, capital, and profit',
      'shopProfile': 'Shop profile',
      'shopProfileDesc': 'Business name, address, and phone',
      'accountSecurity': 'Account security',
      'accountSecurityDesc': 'Login and account protection',
      'privacy': 'Privacy',
      'privacyDesc': 'Data and privacy controls',
      'signOut': 'Sign out',
      'signOutDesc': 'Leave this account',
    },
    'bn': {
      'appName': 'হালখাতা',
      'dashboard': 'ড্যাশবোর্ড',
      'home': 'হোম',
      'menu': 'মেনু',
      'more': 'মেনু',
      'sales': 'বিক্রয়',
      'pos': 'পস',
      'stock': 'স্টক',
      'customer': 'কাস্টার',
      'customers': 'কাস্টমার',
      'clients': 'ক্লায়েন্ট',
      'due': 'বাকি',
      'products': 'পণ্য',
      'purchase': 'ক্রয়',
      'investments': 'বিনিয়োগ',
      'settings': 'সেটিংস',
      'todaySales': 'আজকের বিক্রয়',
      'totalDue': 'মোট বাকি',
      'customersDue': 'বাকি কাস্টমার',
      'topSelling': 'সর্বাধিক বিক্রিত পণ্য',
      'lowStock': 'কম স্টক পণ্য',
      'monthlySummary': 'মাসিক সারাংশ',
      'addProduct': 'পণ্য যোগ',
      'addCustomer': 'কাস্টমার যোগ',
      'addPayment': 'পেমেন্ট যোগ',
      'ledger': 'খতিয়ান',
      'paid': 'পরিশোধিত',
      'partial': 'আংশিক',
      'cash': 'ক্যাশ',
      'bkash': 'বিকাশ',
      'nagad': 'নগদ',
      'language': 'ভাষা',
      'english': 'ইংরেজি',
      'bangla': 'বাংলা',
      'offlineReady': 'অফলাইন প্রস্তুত',
      'syncNow': 'সিঙ্ক করুন',
      'owner': 'মালিক',
      'staff': 'স্টাফ',
      'login': 'ফোন লগইন',
      'sectionOperations': 'অপারেশন',
      'sectionFinance': 'ফাইন্যান্স',
      'sectionApp': 'অ্যাপ',
      'productsDesc': 'স্টক, দাম ও বারকোড',
      'customersDesc': 'প্রোফাইল, বাকি ও খতিয়ান',
      'vendors': 'সাপ্লায়ার',
      'vendorsDesc': 'ক্রয় ও সাপ্লায়ার স্টক',
      'generateReceipt': 'চেকআউট',
      'receiptsDesc': 'কাস্টমার রসিদ তৈরি',
      'duesDesc': 'কাস্টমার বাকি ও পেমেন্ট',
      'investmentsDesc': 'মালিক, পুঁজি ও লাভ',
      'shopProfile': 'দোকান প্রোফাইল',
      'shopProfileDesc': 'ব্যবসার নাম, ঠিকানা ও ফোন',
      'accountSecurity': 'অ্যাকাউন্ট সিকিউরিটি',
      'accountSecurityDesc': 'লগইন ও অ্যাকাউন্ট সুরক্ষা',
      'privacy': 'প্রাইভেসি',
      'privacyDesc': 'ডাটা ও প্রাইভেসি নিয়ন্ত্রণ',
      'signOut': 'সাইন আউট',
      'signOutDesc': 'এই অ্যাকাউন্ট থেকে বের হন',
    },
  };

  String t(String key) =>
      _values[locale.languageCode]?[key] ?? _values['en']![key] ?? key;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'bn'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
