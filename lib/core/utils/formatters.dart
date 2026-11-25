import 'package:intl/intl.dart';

class AppFormatters {
  static int decimalsForCurrency(String currencyCode) {
    switch (currencyCode.toUpperCase()) {
      case 'MMK':
      case 'JPY':
      case 'KRW':
      case 'VND':
        return 0;
      default:
        return 2;
    }
  }

  static String symbolForCurrency(String currencyCode) {
    switch (currencyCode.toUpperCase()) {
      case 'MMK':
        return 'Ks';
      case 'USD':
        return '\$';
      case 'THB':
        return '฿';
      case 'SGD':
        return 'S\$';
      case 'EUR':
        return '€';
      default:
        return currencyCode.toUpperCase();
    }
  }

  static String formatAmount(double amount, String currencyCode) {
    final decimals = decimalsForCurrency(currencyCode);
    final isWhole = (amount - amount.roundToDouble()).abs() < 0.005;
    final pattern = (decimals == 0 || isWhole) ? '#,##0' : '#,##0.00';
    final formatted = NumberFormat(pattern).format(amount);
    final symbol = symbolForCurrency(currencyCode);
    if (currencyCode.toUpperCase() == 'MMK') {
      return '$formatted $symbol';
    }
    return '$symbol$formatted';
  }

  static String formatSignedAmount(double amount, String currencyCode) {
    if (amount.abs() < 0.005) {
      return formatAmount(0, currencyCode);
    }
    final prefix = amount > 0 ? '+' : '-';
    return '$prefix${formatAmount(amount.abs(), currencyCode)}';
  }

  static String formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  static String formatShortDate(DateTime date) {
    return DateFormat('dd MMM').format(date);
  }

  static String formatDateRange(DateTime start, DateTime? end) {
    if (end == null) {
      return '${formatShortDate(start)} – Now';
    }
    return '${formatShortDate(start)} – ${formatDate(end)}';
  }
}
