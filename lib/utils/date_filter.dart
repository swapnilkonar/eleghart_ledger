import 'package:flutter/material.dart';

enum DateFilterType { currentMonth, lastMonth, allTime, custom }

class DateFilter {
  static final ValueNotifier<DateFilterType> notifier =
      ValueNotifier(DateFilterType.currentMonth);

  static DateTime? customMonth; // set when type == custom

  static DateFilterType get current => notifier.value;

  static String get label {
    final now = DateTime.now();
    switch (notifier.value) {
      case DateFilterType.currentMonth:
        return _monthName(now.month, now.year);
      case DateFilterType.lastMonth:
        final last = DateTime(now.year, now.month - 1);
        return _monthName(last.month, last.year);
      case DateFilterType.allTime:
        return 'All Time';
      case DateFilterType.custom:
        if (customMonth != null) {
          return _monthName(customMonth!.month, customMonth!.year);
        }
        return 'Custom';
    }
  }

  static String monthName(int month, int year) => _monthName(month, year);

  static String _monthName(int month, int year) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[month - 1]} $year';
  }

  static bool isInRange(DateTime date) {
    final now = DateTime.now();
    switch (notifier.value) {
      case DateFilterType.currentMonth:
        return date.year == now.year && date.month == now.month;
      case DateFilterType.lastMonth:
        final last = DateTime(now.year, now.month - 1);
        return date.year == last.year && date.month == last.month;
      case DateFilterType.allTime:
        return true;
      case DateFilterType.custom:
        if (customMonth == null) return true;
        return date.year == customMonth!.year &&
            date.month == customMonth!.month;
    }
  }

  static void setCustomMonth(int year, int month) {
    customMonth = DateTime(year, month);
    notifier.value = DateFilterType.custom;
    // Force listeners to rebuild even if value was already custom
    notifier.notifyListeners();
  }
}
