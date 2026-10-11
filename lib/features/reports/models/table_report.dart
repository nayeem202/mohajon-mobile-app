import '../../../core/localization/app_localizations.dart';

class ReportSummary {
  const ReportSummary({
    required this.label,
    required this.value,
    this.accent = 0xFF1E3A8A,
  });

  final String label;
  final String value;
  final int accent;
}

class ReportTableColumn {
  const ReportTableColumn({
    required this.key,
    required this.header,
    this.weight = 1,
    this.rightAlign = false,
  });

  final String key;
  final String header;
  final double weight;
  final bool rightAlign;
}

class ReportTableData {
  const ReportTableData({
    required this.title,
    required this.subtitle,
    required this.columns,
    required this.rows,
    this.summaries = const [],
  });

  final String title;
  final String subtitle;
  final List<ReportTableColumn> columns;
  final List<Map<String, Object?>> rows;
  final List<ReportSummary> summaries;
}

/// Localizes report metadata for exported PDF/XLSX files while preserving
/// user-entered names and row values exactly as stored.
ReportTableData localizedReportTable(
  ReportTableData table,
  AppLocalizations l10n,
) {
  if (l10n.locale.languageCode != 'bn') return table;
  const labels = <String, String>{
    'Due Payments': 'বকেয়া আদায়',
    'All time': 'সর্বমোট সময়',
    'Total Due': 'মোট বকেয়া',
    'Customers': 'কাস্টমার',
    'Avg Due': 'গড় বকেয়া',
    'Open Sales': 'বকেয়া বিক্রি',
    'Customer': 'কাস্টমার',
    'Phone': 'ফোন',
    'Due Amount': 'বকেয়া টাকা',
    'Payment Methods': 'পেমেন্টের মাধ্যম',
    'Payments': 'পেমেন্ট সংখ্যা',
    'Received': 'আদায়',
    'Methods Used': 'ব্যবহৃত মাধ্যম',
    'Top Method': 'সবচেয়ে ব্যবহৃত মাধ্যম',
    'Method': 'মাধ্যম',
    'Amount': 'টাকার পরিমাণ',
    'Daily Transactions': 'দৈনিক লেনদেন',
    'Transactions': 'লেনদেন',
    'Sales Amount': 'বিক্রির টাকা',
    'Active Days': 'বিক্রির দিন',
    'Date': 'তারিখ',
    'Sales': 'বিক্রি',
    'Product-wise Sales': 'পণ্যভিত্তিক বিক্রি',
    'Products Sold': 'বিক্রি হওয়া পণ্য',
    'Total Revenue': 'মোট বিক্রির টাকা',
    'Total Profit': 'মোট লাভ',
    'Top Selling Product': 'সর্বাধিক বিক্রি হওয়া পণ্য',
    'Product': 'পণ্য',
    'Qty': 'পরিমাণ',
    'Revenue': 'বিক্রির টাকা',
    'Profit': 'লাভ',
    'VAT Report': 'ভ্যাট রিপোর্ট',
    'Total VAT': 'মোট ভ্যাট',
    'Vatable Sales': 'ভ্যাটযোগ্য বিক্রি',
    'Avg VAT / Sale': 'প্রতি বিক্রিতে গড় ভ্যাট',
    'Avg Rate': 'গড় হার',
    'Invoice': 'ইনভয়েস',
    'Subtotal': 'উপমোট',
    'VAT %': 'ভ্যাট %',
    'VAT Amount': 'ভ্যাটের পরিমাণ',
    'Profit & Loss': 'লাভ-ক্ষতির হিসাব',
    'Gross Profit': 'মোট লাভ',
    'Expenses': 'খরচ',
    'Net Profit': 'নিট লাভ',
    'Item': 'বিবরণ',
    'Sales paid': 'বিক্রিতে আদায়',
    'Collections': 'বাকি আদায়',
    'Expected closing': 'সম্ভাব্য জমা',
    'Expected cash': 'সম্ভাব্য নগদ',
    'Supplier': 'সরবরাহকারী',
    'Orders': 'অর্ডার',
    'Purchase': 'ক্রয়',
    'Paid': 'পরিশোধিত',
    'Due': 'বাকি',
    'Total purchase': 'মোট ক্রয়',
    'Suppliers': 'সরবরাহকারী',
    'In': 'প্রবেশ',
    'Sold': 'বিক্রি',
    'Stock': 'স্টক',
    'Stock value': 'স্টকের মূল্য',
    'Products': 'পণ্য',
    'Dead stock': 'অবিক্রীত পণ্য',
    'Last activity': 'সর্বশেষ কার্যক্রম',
    'Risk': 'ঝুঁকি',
    'Total due': 'মোট বকেয়া',
    'Customers at risk': 'ঝুঁকিতে থাকা কাস্টমার',
    'Category': 'ক্যাটাগরি',
    'Margin': 'লাভের হার',
    'Staff': 'কর্মী',
    'Collected': 'আদায়',
    'Discount': 'ছাড়',
    'Staff with sales': 'বিক্রি করা কর্মী',
    'Unattributed': 'কর্মী নির্ধারিত নয়',
    'Area': 'এলাকা',
    'Pending / deleted': 'অমীমাংসিত / মুছে ফেলা',
    'Audit status': 'অডিট অবস্থা',
    'Period': 'সময়কাল',
    'Report Type': 'রিপোর্টের ধরন',
  };
  String localize(String text) => labels[text] ?? text;
  return ReportTableData(
    title: localize(table.title),
    subtitle: localize(table.subtitle),
    summaries: table.summaries
        .map(
          (item) => ReportSummary(
            label: localize(item.label),
            value: item.value,
            accent: item.accent,
          ),
        )
        .toList(growable: false),
    columns: table.columns
        .map(
          (column) => ReportTableColumn(
            key: column.key,
            header: localize(column.header),
            weight: column.weight,
            rightAlign: column.rightAlign,
          ),
        )
        .toList(growable: false),
    rows: table.rows,
  );
}
