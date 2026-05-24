# lib/screens/ — AI Context

## What's here
All 15 screen files. Each is a StatefulWidget with a Scaffold body.

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
| GroupsScreen | groups_screen.dart | (parent) | YES |
| GroupDetailScreen | group_detail_screen.dart | 0.72 | Partial* |
| AddExpenseScreen | add_expense_screen.dart | 0.72 | No |
| CreateGroupScreen | create_group_screen.dart | 0.70 | No |
| CategoriesListScreen | categories_list_screen.dart | 0.72 | No |
| CategoryDetailScreen | category_detail_screen.dart | 0.72 | No |
| ExportPdfScreen | export_pdf_screen.dart | 0.72 | No |
| ProfileSheet | profile_sheet.dart | BottomSheet | No |

*GroupDetailScreen: empty-state image uses ValueListenableBuilder at line ~572

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
- `AddExpenseScreen` → pops with `ExpenseModel?` (null if cancelled)
- `CreateGroupScreen` → pops with `GroupModel?` (null if cancelled)
- All others → no meaningful return value
