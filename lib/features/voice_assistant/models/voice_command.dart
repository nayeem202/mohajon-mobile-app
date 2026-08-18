enum VoiceCommandType {
  openHome,
  openSales,
  openProducts,
  openCustomers,
  openMore,
  openNotifications,
  openInvestors,
  openExpenses,
  unknown,
}

class VoiceCommand {
  const VoiceCommand({required this.type, required this.transcript});

  final VoiceCommandType type;
  final String transcript;

  bool get isKnown => type != VoiceCommandType.unknown;

  String get label => switch (type) {
        VoiceCommandType.openHome => 'Home খুলছি',
        VoiceCommandType.openSales => 'Sales খুলছি',
        VoiceCommandType.openProducts => 'Products খুলছি',
        VoiceCommandType.openCustomers => 'Customers খুলছি',
        VoiceCommandType.openMore => 'More খুলছি',
        VoiceCommandType.openNotifications => 'Notifications খুলছি',
        VoiceCommandType.openInvestors => 'Investors খুঁজছি',
        VoiceCommandType.openExpenses => 'Expenses খুঁজছি',
        VoiceCommandType.unknown => 'Command বোঝা যায়নি',
      };
}

class VoiceCommandParser {
  static VoiceCommand parse(String transcript) {
    final text = transcript.trim().toLowerCase();
    if (text.isEmpty) {
      return VoiceCommand(type: VoiceCommandType.unknown, transcript: transcript);
    }

    if (_containsAny(text, ['notification', 'নোটিফিকেশন', 'বিজ্ঞপ্তি'])) {
      return VoiceCommand(type: VoiceCommandType.openNotifications, transcript: transcript);
    }
    if (_containsAny(text, ['investor', 'investment', 'ইনভেস্টর', 'বিনিয়োগ'])) {
      return VoiceCommand(type: VoiceCommandType.openInvestors, transcript: transcript);
    }
    if (_containsAny(text, ['expense', 'expenses', 'খরচ'])) {
      return VoiceCommand(type: VoiceCommandType.openExpenses, transcript: transcript);
    }
    if (_containsAny(text, ['product', 'products', 'stock', 'পণ্য', 'স্টক'])) {
      return VoiceCommand(type: VoiceCommandType.openProducts, transcript: transcript);
    }
    if (_containsAny(text, ['customer', 'customers', 'client', 'ক্রেতা', 'কাস্টমার'])) {
      return VoiceCommand(type: VoiceCommandType.openCustomers, transcript: transcript);
    }
    if (_containsAny(text, ['sale', 'sales', 'sell', 'বিক্রি', 'সেল'])) {
      return VoiceCommand(type: VoiceCommandType.openSales, transcript: transcript);
    }
    if (_containsAny(text, ['more', 'আরও', 'মোর'])) {
      return VoiceCommand(type: VoiceCommandType.openMore, transcript: transcript);
    }
    if (_containsAny(text, ['home', 'dashboard', 'হোম', 'ড্যাশবোর্ড'])) {
      return VoiceCommand(type: VoiceCommandType.openHome, transcript: transcript);
    }
    return VoiceCommand(type: VoiceCommandType.unknown, transcript: transcript);
  }

  static bool _containsAny(String text, List<String> values) =>
      values.any(text.contains);
}
