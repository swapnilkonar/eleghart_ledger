# lib/screens/ — AI Context

## What's here
21 screen files. Each is a StatefulWidget with a Scaffold body.

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
| Screen | File | Overlay | Theme Listener | Notes |
|--------|------|---------|---------------|-------|
| PremiumSplashScreen | splash_screen.dart | — | No | |
| PremiumOnboardingScreen | premium_onboarding_screen.dart | white bg / gradient | No | ✅ theme-aware |
| WelcomeScreen | welcome_screen.dart | 0.40 | No | ✅ theme-aware |
| OnboardingScreen | onboarding_screen.dart | 0.40 | No | ✅ theme-aware |
| SetPinScreen | set_pin_screen.dart | 0.25 | YES | |
| PinUnlockScreen | pin_unlock_screen.dart | 0.25 | YES | |
| HomeDashboard | home_dashboard.dart | 0.65 | YES | Has Wealth snapshot card |
| **ExpenseListScreen** | expense_list_screen.dart | (parent) | YES | |
| **ExpensesScreen** | expenses_screen.dart | own Scaffold | YES | |
| **ExtractedExpensesScreen** | extracted_expenses_screen.dart | 0.72 | No | |
| GroupsScreen | groups_screen.dart | (parent) | YES | |
| GroupDetailScreen | group_detail_screen.dart | 0.72 | Partial* | |
| AddExpenseScreen | add_expense_screen.dart | 0.72 | No | |
| CreateGroupScreen | create_group_screen.dart | 0.70 | No | |
| CategoriesListScreen | categories_list_screen.dart | 0.72 | No | |
| CategoryDetailScreen | category_detail_screen.dart | 0.72 | No | |
| ExportPdfScreen | export_pdf_screen.dart | 0.72 | No | |
| ProfileSheet | profile_sheet.dart | BottomSheet | No | |
| **WealthDashboardScreen** | wealth_dashboard_screen.dart | 0.65 | No | Wealth Journey entry |
| **GoalDetailScreen** | goal_detail_screen.dart | 0.65 | No | PopScope back, edit ✏️ |
| **CreateGoalScreen** | create_goal_screen.dart | 0.65 | No | create + edit mode |

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
- `GoalDetailScreen` → pops with `WealthGoal` (always, via PopScope)
- `CreateGoalScreen` → pops with `WealthGoal` (saved) or null (cancelled)
- All others → no meaningful return value

## Wealth Journey Screens

### WealthDashboardScreen
```
File:    lib/screens/wealth_dashboard_screen.dart
Access:  HomeDashboard Quick Action (Wealth icon) OR Wealth snapshot card
State:   _goals:List<WealthGoal>, _loading:bool, _animCtrl
Reload:  _load() called in initState AND unconditionally after every Navigator.push
Cards:   _buildGoalCard() shows "Month X of Y" (min Month 1), progress bar, health badge
```

### GoalDetailScreen
```
File:    lib/screens/goal_detail_screen.dart
State:   _goal (mutable), _contributions, _loading, _progressAnim
AppBar:  Back (←) + Goal name + Edit pencil (✏️ red)
Edit ✏️: opens CreateGoalScreen(goal: _goal) → on return setState(_goal = updated)
FAB:     'Add Contribution' → _showAddContribution() bottom sheet
Bottom sheet has:
  - Credit/Debit toggle (green ↑ / red ↓)
  - Amount field (₹ prefix color matches toggle)
  - Date picker
  - Notes field
  - Save Credit / Save Debit button (color matches toggle)
Contribution list: ↑ green circle = credit (+), ↓ red circle = debit (−)
PopScope: hardware/gesture back always pops with latest _goal
```

### CreateGoalScreen
```
File:    lib/screens/create_goal_screen.dart
Constructor: CreateGoalScreen({goal: WealthGoal?})
Create mode (goal==null): all fields shown, 'Create Goal' button, calls insertGoal()
Edit mode (goal!=null):   Starting Amount hidden, 'Save Changes' button, calls updateGoal()
                          Constructs WealthGoal directly (never copyWith) to allow notes=null
initState: pre-fills all fields from widget.goal when editing
Returns:   Navigator.pop(context, WealthGoal) on success
```

## Goal Status Card (in GoalDetailScreen)
```
Expected: WealthService.expectedSaved() — month-based, min 1 month elapsed → always non-zero
Actual:   _goal.currentAmount
Gap:      WealthService.gap() — max(0, expected - actual)
Health:   Ahead / On Track / Slightly Behind / Critical
```
