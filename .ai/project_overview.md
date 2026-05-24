# Eleghart Ledger — AI Super Map v1

## READ THIS FIRST — What the AI needs to know before touching any file

### App in one sentence
Flutter personal finance ledger: users create Groups, log Debit/Credit expenses per group, view summaries, export PDF, protected by PIN. No backend — 100% local SharedPreferences.

### Tech Stack (exact)
- Flutter/Dart · SharedPreferences · google_fonts · fl_chart · pdf+printing · share_plus · image_picker · uuid · smooth_page_indicator · open_filex
- NO: Firebase, Riverpod, Provider, Bloc, Hive, SQLite

### State Management Rule
`ValueNotifier` for cross-widget state, `setState` for local. Add `addListener(_onX)` in `initState`, remove in `dispose`. See `AppThemeNotifier` as the canonical example.

### Theme System (DO NOT CHANGE THE PATTERN)
```
AppThemeNotifier.instance  →  ValueNotifier<bool> (true = white theme)
AppThemeNotifier.isWhite   →  bool getter (reads instance.value)
AppThemeNotifier.toggle()  →  flips + persists to SharedPreferences
AppThemeNotifier.initialize() → called in main() before runApp()
```
Every screen that has theme-sensitive UI must:
1. Add `AppThemeNotifier.instance.addListener(_onThemeChanged)` in `initState`
2. Add `void _onThemeChanged() => setState(() {});` method
3. Add `AppThemeNotifier.instance.removeListener(_onThemeChanged)` in `dispose`
4. Use `AppThemeNotifier.isWhite ? lightColor : darkColor` inline

### Background Pattern (ALL screens use this)
Every Scaffold body is a Stack. First child is ALWAYS:
```dart
Positioned.fill(child: ThemedBackground(darkOverlayOpacity: X))
```
Overlay values: splash/pin screens=0.25, onboarding/welcome=0.40, home/groups=0.65, detail screens=0.72

### Navigation Flow
```
main() → PremiumSplashScreen (3s animated)
  ├── [new user]     → WelcomeScreen → OnboardingScreen → SetPinScreen → HomeDashboard
  └── [returning]    → PinUnlockScreen → HomeDashboard
                                         └── Tab 0: HomeTab (summary + quick stats)
                                             Tab 1: GroupsScreen (list + stats card)
                                             Tab 2: Insights (placeholder)
                                             Tab 3: Profile (placeholder)
GroupsScreen → GroupDetailScreen → AddExpenseScreen
                                 → ExportPdfScreen
                                 → CategoriesListScreen → CategoryDetailScreen
HomeDashboard appbar avatar icon → ProfileSheet (BottomSheet)
```

### Data Keys in SharedPreferences
| Key | Type | Value |
|-----|------|-------|
| `groups_v2` | StringList | JSON-encoded GroupModel list |
| `expenses_v2` | StringList | JSON-encoded ExpenseModel list |
| `category_images_v1` | String | JSON map {categoryName: filePath} |
| `is_white_theme` | bool | theme preference |
| `user_name` | String | display name |
| `user_avatar_path` | String | local file path |
| `pin_set` | bool | whether PIN has been configured |
| `user_pin` | String | 4-digit PIN (plaintext) |
| `has_seen_onboarding` | bool | skip onboarding flag |

### Asset Paths
```
assets/images/background_theme_top_glow.png  ← dark theme bg
assets/images/background_theme_white.png     ← white theme bg
assets/images/empty_expenses.png             ← dark theme empty state
assets/images/empty_expenses_white.png       ← white theme empty state
assets/images/splash_screen_white.png        ← white theme splash image
assets/icons/eleghart_icon.png               ← app logo
```

### Color System
All colors live in `lib/theme/eleghart_colors.dart` as `EleghartColors.*`
- Accent red: `accentDark=#8E1D1D`, `accentMid=#B32626`, `accentLight=#C73535`
- Text: `textPrimary=#0F172A`, `textSecondary=#6B7280`, `textHint=#9CA3AF`
- Backgrounds: `bgLight=#E5E7EB`, `cardBg=#FFFFFF`, `inputBg=#FFFFFF`
- Divider: `divider=#E5E7EB`

### White Theme Card Standard (applied to ALL screens)
```dart
// Card container BoxDecoration — white theme
BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),  // or 14/18/20 per context
  border: Border.all(color: const Color(0xFFEEEEEE), width: 1),
  boxShadow: [BoxShadow(
    color: const Color(0xFFCC0020).withOpacity(0.10),  // subtle red shadow
    blurRadius: 10,
    offset: Offset(0, 2),
  )],
)
// Bottom sheets — white theme background: Colors.white
// Dark theme cards remain unchanged (dark bg + red tint borders)
```

### Font
Always `GoogleFonts.sora(...)`. Never use default TextStyle font family.
