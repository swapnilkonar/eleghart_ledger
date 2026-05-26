# lib/screens/ — AI Context

## What's here
18 screen files. Each is a StatefulWidget with a Scaffold body.

## Universal Pattern in EVERY screen
```dart
Scaffold(
  backgroundColor: Colors.black,
  body: Stack(children: [
    Positioned.fill(child: ThemedBackground(darkOverlayOpacity: X)),
    SafeArea(child: ...),
  ]),
)
```

## Screen → File Map
| Screen | File | Overlay | Theme Listener |
|--------|------|---------|---------------|
| PremiumSplashScreen | splash_screen.dart | — | No |
| PremiumOnboardingScreen | premium_onboarding_screen.dart | No bg | No |
| WelcomeScreen | welcome_screen.dart | 0.40 | No |
| OnboardingScreen | onboarding_screen.dart | 0.40 | No |
| SetPinScreen | set_pin_screen.dart | 0.25 | YES |
| PinUnlockScreen | pin_unlock_screen.dart | 0.25 | YES |
| HomeDashboard | home_dashboard.dart | 0.65 | YES |
| **ExpenseListScreen** | expense_list_screen.dart | (parent) | YES |
| **ExpensesScreen** | expenses_screen.dart | own Scaffold | YES |
| **ExtractedExpensesScreen** | extracted_expenses_screen.dart | 0.72 | No |
| GroupsScreen | groups_screen.dart | (parent) | YES |
| GroupDetailScreen | group_detail_screen.dart | 0.72 | Partial* |
| AddExpenseScreen | add_expense_screen.dart | 0.72 | No |
| CreateGroupScreen | create_group_screen.dart | 0.70 | No |
| CategoriesListScreen | categories_list_screen.dart | 0.72 | No |
| CategoryDetailScreen | category_detail_screen.dart | 0.72 | No |
| ExportPdfScreen | export_pdf_screen.dart | 0.72 | No |
| ProfileSheet | profile_sheet.dart | BottomSheet | No |

*GroupDetailScreen: empty-state image uses ValueListenableBuilder at line ~572

## HomeDashboard Tabs (IndexedStack)
| Index | Widget | GlobalKey |
|-------|--------|-----------|
| 0 | HomeTab (summary) | — |
| 1 | ExpenseListScreen | `_expenseListKey` |
| 2 | GroupsScreen | `_groupsKey` |
| 3 | Insights placeholder | — |

**Tab switching**: always use `_switchTab(index)` — it calls `_expenseListKey.currentState?.reload()` when switching to tab 1.

## ExpenseListScreen Key API
```dart
// GlobalKey usage from HomeDashboard:
_expenseListKey.currentState?.reload();

// Widget constructor:
ExpenseListScreen(key: _expenseListKey, onExpenseAdded: _onExpenseAdded)

// Public method:
void reload() async { /* reloads expenses + groups from StorageService */ }
```

## ExpensesScreen — AI Upload Hub
```
File: lib/screens/expenses_screen.dart
Access: pushed from ExpenseListScreen._openAddExpense() (FAB)
State fields: _processing, _progress, _statusText, _pdfToastVisible, _pdfToastSuccess,
              _pdfToastTitle, _pdfToastSubtitle, _toastTimer
Key methods:
  _pickCamera()       → image_picker camera → _runAI(file, name, isPdf:false)
  _pickGallery()      → image_picker gallery → _runAI(file, name, isPdf:false)
  _pickPdf()          → file_picker PDF → _showPdfPasswordDialog() → _runAI()
  _runAI(file, name, {isPdf}) → AIExtractionService → ExtractedExpensesScreen
  _showPdfPasswordDialog() → Dialog with lock icon, password field, Cancel+Unlock PDF
  _triggerToast({success,title,subtitle,autoDismiss}) → AnimatedPositioned toast
  _dismissToast()     → cancels Timer, hides toast
  _openAddManually()  → group picker BottomSheet → AddExpenseScreen
Build: returns Stack(Scaffold + AnimatedPositioned toast)
```

## ExtractedExpensesScreen — AI Review
```
File: lib/screens/extracted_expenses_screen.dart
Constructor: ExtractedExpensesScreen({items: List<ExtractedItem>, sourceName: String})
ExtractedItem fields: id, description, amount, category, date
Features: edit each item, select/deselect, assign group, bulk save
```

## Theme Listener Pattern (copy-paste template)
```dart
@override
void initState() {
  super.initState();
  AppThemeNotifier.instance.addListener(_onThemeChanged);
  // ... rest of initState
}

void _onThemeChanged() => setState(() {});

@override
void dispose() {
  AppThemeNotifier.instance.removeListener(_onThemeChanged);
  // ... rest of dispose
  super.dispose();
}
```

## Navigation Return Values
- `GroupDetailScreen` → pops with `bool _dataChanged`
- `AddExpenseScreen` → pops with `true` (saved) or nothing (cancelled)
- `CreateGroupScreen` → pops with `GroupModel?` (null if cancelled)
- `ExpensesScreen` → no return value (ExpenseListScreen reloads on return via _openAddExpense)
- `ExtractedExpensesScreen` → no return value (saves to StorageService directly)
- All others → no meaningful return value
