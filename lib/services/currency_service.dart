class CurrencyInfo {
  final String code;
  final String name;
  final String symbol;
  final double rateToInr; // Approx exchange rate relative to INR for fallback

  const CurrencyInfo({
    required this.code,
    required this.name,
    required this.symbol,
    required this.rateToInr,
  });
}

class CurrencyService {
  static const List<CurrencyInfo> currencies = [
    CurrencyInfo(code: 'INR', name: 'Indian Rupee', symbol: '₹', rateToInr: 1.0),
    CurrencyInfo(code: 'USD', name: 'US Dollar', symbol: '\$', rateToInr: 83.5),
    CurrencyInfo(code: 'EUR', name: 'Euro', symbol: '€', rateToInr: 90.2),
    CurrencyInfo(code: 'GBP', name: 'British Pound', symbol: '£', rateToInr: 106.5),
    CurrencyInfo(code: 'AED', name: 'UAE Dirham', symbol: 'AED', rateToInr: 22.7),
    CurrencyInfo(code: 'THB', name: 'Thai Baht', symbol: '฿', rateToInr: 2.3),
    CurrencyInfo(code: 'JPY', name: 'Japanese Yen', symbol: '¥', rateToInr: 0.55),
    CurrencyInfo(code: 'CAD', name: 'Canadian Dollar', symbol: 'CA\$', rateToInr: 61.5),
    CurrencyInfo(code: 'AUD', name: 'Australian Dollar', symbol: 'A\$', rateToInr: 55.8),
    CurrencyInfo(code: 'SGD', name: 'Singapore Dollar', symbol: 'S\$', rateToInr: 62.4),
  ];

  static CurrencyInfo getCurrency(String code) {
    return currencies.firstWhere(
      (c) => c.code.toUpperCase() == code.toUpperCase(),
      orElse: () => const CurrencyInfo(code: 'INR', name: 'Indian Rupee', symbol: '₹', rateToInr: 1.0),
    );
  }

  static String getSymbol(String code) {
    return getCurrency(code).symbol;
  }

  /// Calculates estimated exchange rate from fromCurrency to toCurrency
  static double getExchangeRate(String fromCurrency, String toCurrency) {
    if (fromCurrency.toUpperCase() == toCurrency.toUpperCase()) return 1.0;
    final from = getCurrency(fromCurrency);
    final to = getCurrency(toCurrency);
    if (to.rateToInr == 0) return 1.0;
    return from.rateToInr / to.rateToInr;
  }

  /// Formats amount with currency symbol
  static String formatAmount(double amount, String currencyCode) {
    final symbol = getSymbol(currencyCode);
    final formatted = amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2);
    if (currencyCode.toUpperCase() == 'AED') {
      return '$symbol $formatted';
    }
    return '$symbol$formatted';
  }
}
