import 'package:intl/intl.dart';

import '../constants/app_constants.dart';

String money(num value) {
  final formatter = NumberFormat.currency(
    locale: 'en_BD',
    symbol: '${AppConstants.defaultCurrency} ',
    decimalDigits: value % 1 == 0 ? 0 : 2,
  );
  return formatter.format(value);
}
