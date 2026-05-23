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
      'appName': 'Hishab Bondhu',
      'dashboard': 'Dashboard',
      'sales': 'Sales',
      'customer': 'Customer',
      'customers': 'Customers',
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
      'pos': 'POS',
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
    },
    'bn': {
      'appName': 'হিসাব বন্ধু',
      'dashboard': 'ড্যাশবোর্ড',
      'sales': 'বিক্রয়',
      'customer': 'কাস্টার',
      'customers': 'কাস্টমার',
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
      'pos': 'পস',
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
    },
  };

  String t(String key) => _values[locale.languageCode]?[key] ?? _values['en']![key] ?? key;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'bn'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
