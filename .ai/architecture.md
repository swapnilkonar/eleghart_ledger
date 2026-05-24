# Architecture — Eleghart Ledger

## Screen Body Pattern (UNIVERSAL)
Every screen Scaffold body:
```dart
Stack(
  children: [
    Positioned.fill(child: ThemedBackground(darkOverlayOpacity: X)),  // ALWAYS first
    SafeArea(child: ...content...),                                     // or Column directly
  ],
)
```

## Data Lifecycle
```
Load:   StorageService.loadGroups()    → setState(_groups = ...)
        StorageService.loadExpenses()  → setState(_expenses = ...)
Save:   await StorageService.saveGroups(_groups)
        await StorageService.saveExpenses(_expenses)
Scope:  Each screen loads its own data in initState / _loadData()
        No shared app-level state store.
```

## Cross-Screen Data Passing
```
HomeDashboard → GroupsScreen         : via constructor (userName)
GroupsScreen  → GroupDetailScreen    : Navigator.push, passes group + allExpenses
GroupDetail   → HomeDashboard        : Navigator.pop(context, _dataChanged:bool)
                                       HomeDashboard reloads if dataChanged==true
GroupDetail   → AddExpenseScreen     : Navigator.push, returns new ExpenseModel or null
GroupDetail   → ExportPdfScreen      : Navigator.push, passes group + filtered expenses
GroupsScreen  → CategoriesListScreen : Navigator.push, passes allGroups + allExpenses
Categories    → CategoryDetailScreen : Navigator.push, passes category string + data
```

## Theme Reactivity
```
AppThemeNotifier.instance (ValueNotifier<bool>)
    │
    ├── ThemedBackground widget ← has own ValueListenableBuilder, auto-rebuilds
    ├── HomeDashboard._onThemeChanged()
    ├── GroupsScreen._onThemeChanged()
    ├── GroupDetailScreen._onThemeChanged()
    ├── AddExpenseScreen._onThemeChanged()
    ├── CategoriesListScreen._onFilter()  ← shared with DateFilter listener
    ├── CategoryDetailScreen._onFilter()  ← shared with DateFilter listener
    ├── CreateGroupScreen._onThemeChanged()
    ├── PinUnlockScreen._onThemeChanged()
    ├── SetPinScreen._onThemeChanged()
    └── DateFilterPill._onFilterChanged()  ← shared with DateFilter listener

Toggle source: ProfileSheet SwitchListTile → AppThemeNotifier.toggle()
```

## White Theme Card Pattern
```dart
// Use this BoxDecoration for ALL cards in white theme:
BoxDecoration(
  color: AppThemeNotifier.isWhite ? Colors.white : const Color(0xFF0E0505),
  borderRadius: BorderRadius.circular(16),
  border: Border.all(
    color: AppThemeNotifier.isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.07),
    width: 1,
  ),
  boxShadow: AppThemeNotifier.isWhite
      ? [BoxShadow(color: const Color(0xFFCC0020).withOpacity(0.10), blurRadius: 10, offset: Offset(0, 2))]
      : [],
)
// Bottom sheet bg: AppThemeNotifier.isWhite ? Colors.white : const Color(0xFF120404)
// Text on cards (white theme): AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white
```

## Date Filtering
```
DateFilter.notifier (ValueNotifier<DateFilterType>)
    │
    ├── GroupsScreen.addListener(_onFilterChanged) → setState
    └── DateFilterPill widget ← drives the notifier

Filter check: DateFilter.isInRange(expense.date) returns bool
Types: currentMonth | lastMonth | allTime | custom(specific month)
```

## AddExpense Save Flow
```
1. User fills form in AddExpenseScreen
2. Creates ExpenseModel(id=UUID, groupId, amount, type, categories, date, imagePath)
3. Appends to list: _expenses.add(newExpense)
4. StorageService.saveExpenses(_expenses)
5. Navigator.pop(context, newExpense)
6. GroupDetailScreen receives it, adds to local list, setState
```

## PDF Export Flow
```
GroupDetailScreen → ExportPdfScreen(group, filteredExpenses)
    → PdfExportService.generateAndSharePdf(group, expenses)
    → Creates pdf.Document, builds tables
    → Saves to temp file
    → share_plus ShareXFiles OR open_filex OpenFile.open()
```

## PIN Flow
```
First launch: SetPinScreen → prefs.setString('user_pin', pin) + prefs.setBool('pin_set', true)
Return visit: PinUnlockScreen reads prefs.getString('user_pin'), compares
Reset PIN:    Dialog confirm → Navigator.pushReplacement(SetPinScreen)
Change PIN:   ProfileSheet → same as reset
```
