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

/// Rounds a monetary value to 2 decimal places (paisa) at the point of
/// arithmetic so stored amounts never carry floating-point dust.
double moneyRound2(num value) => (value * 100).roundToDouble() / 100;
