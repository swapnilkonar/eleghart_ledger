# lib/utils/ — AI Context

## Files
- `app_theme.dart` — Theme state management (ValueNotifier)
- `date_filter.dart` — Global date range filter (ValueNotifier)

## AppThemeNotifier (app_theme.dart, ~19 lines)
```dart
// Static API — use anywhere without instantiation
AppThemeNotifier.instance        // ValueNotifier<bool> — listen to this
AppThemeNotifier.isWhite         // bool getter — read current value
AppThemeNotifier.initialize()    // call in main() before runApp()
AppThemeNotifier.toggle()        // flips value + saves to SharedPreferences
```
SharedPreferences key: `is_white_theme` (bool)

## DateFilter (date_filter.dart, ~65 lines)
```dart
// Enum
enum DateFilterType { currentMonth, lastMonth, allTime, custom }

// Static API
DateFilter.notifier              // ValueNotifier<DateFilterType>
DateFilter.current               // getter → DateFilterType
DateFilter.isInRange(DateTime)   // → bool — use to filter expense lists
DateFilter.label                 // getter → human-readable string e.g. "May 2026"
DateFilter.setCustomMonth(year, month) // sets custom range
DateFilter.customMonth           // DateTime? — set when type == custom
```

## Usage Pattern for Screens
```dart
// In initState:
DateFilter.notifier.addListener(_onFilterChanged);

// Listener:
void _onFilterChanged() => setState(() {});

// In dispose:
DateFilter.notifier.removeListener(_onFilterChanged);

// Filter expenses:
final filtered = _expenses.where((e) => DateFilter.isInRange(e.date)).toList();
```
