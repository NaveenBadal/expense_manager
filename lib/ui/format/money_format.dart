import 'package:intl/intl.dart';

/// Digit grouping differs by currency convention, not just by symbol.
///
/// Indian grouping is 2-2-3 above the thousand: 185000 is written 1,85,000,
/// not 185,000. Formatting rupees with Western grouping makes every large
/// figure read wrong to the people the app is for.
const Map<String, String> _localeForCurrency = {
  'INR': 'en_IN',
  'PKR': 'en_IN',
  'BDT': 'en_IN',
  'NPR': 'en_IN',
  'LKR': 'en_IN',
};

const Map<String, int> _minorDigits = {
  'JPY': 0,
  'KRW': 0,
  'VND': 0,
  'CLP': 0,
  'ISK': 0,
  'BHD': 3,
  'KWD': 3,
  'OMR': 3,
  'JOD': 3,
  'TND': 3,
};

/// Formats [minor] units of [currency] for display.
///
/// Whole amounts drop their empty fraction. A statement listing "2,500.00"
/// beside "699.25" spends width on two zeroes that carry no information, and
/// the ragged decimal column is harder to scan than the numbers themselves.
String formatMoney(int minor, String currency, {bool hidden = false}) {
  if (hidden) return '••••';
  final code = currency.toUpperCase();
  final digits = _minorDigits[code] ?? 2;
  final divisor = digits == 0 ? 1 : _pow10(digits);
  final value = minor / divisor;
  final whole = digits == 0 || minor % divisor == 0;
  // simpleCurrency resolves the code to its symbol (INR -> the rupee sign).
  // NumberFormat.currency would print the code itself as the symbol.
  return NumberFormat.simpleCurrency(
    locale: _localeForCurrency[code],
    name: code,
    decimalDigits: whole ? 0 : digits,
  ).format(value);
}

int _pow10(int exponent) {
  var value = 1;
  for (var i = 0; i < exponent; i++) {
    value *= 10;
  }
  return value;
}
