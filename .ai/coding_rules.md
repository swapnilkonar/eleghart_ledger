# Coding Rules — Eleghart Ledger

## DO
- `GoogleFonts.sora(...)` for ALL text
- `EleghartColors.*` for ALL colors (never raw hex in new code)
- `StorageService` for ALL persistence
- `uuid` package for ALL new IDs: `const Uuid().v4()`
- `Stack > Positioned.fill(child: ThemedBackground(...))` as first body child in every screen
- `AppThemeNotifier.isWhite ? X : Y` for theme-conditional colors
- `addListener` in `initState`, `removeListener` in `dispose` for any `ValueNotifier`

## DO NOT
- Do NOT use Provider, Riverpod, Bloc, GetX, or any state management package
- Do NOT use SQLite, Hive, Firebase, or any network calls
- Do NOT add new SharedPreferences keys without documenting in project_overview.md Data Keys table
- Do NOT use `const` on widgets that contain theme-conditional colors
- Do NOT use `Colors.white` directly in screen text — use conditional with `AppThemeNotifier.isWhite`
- Do NOT call `AppThemeNotifier.toggle()` from `setState` — it triggers its own listeners

## New Screen Checklist
1. Import `themed_background.dart`
2. Import `app_theme.dart` AND `eleghart_colors.dart` if text/colors are theme-sensitive
3. Body is `Stack` with `Positioned.fill(child: ThemedBackground(darkOverlayOpacity: X))` first
4. If theme-sensitive: add `_onThemeChanged` listener pattern
5. `Scaffold(backgroundColor: AppThemeNotifier.isWhite ? Colors.white : Colors.black)`

## White Theme Card Template
```dart
BoxDecoration(
  color: AppThemeNotifier.isWhite ? Colors.white : const Color(0xFF0E0505),
  borderRadius: BorderRadius.circular(16),
  border: Border.all(
    color: AppThemeNotifier.isWhite ? const Color(0xFFEEEEEE) : Colors.white.withOpacity(0.07),
    width: 1,
  ),
  boxShadow: AppThemeNotifier.isWhite
      ? [BoxShadow(color: const Color(0xFFCC0020).withOpacity(0.10), blurRadius: 10, offset: const Offset(0, 2))]
      : [],
)
// For bottom sheets: backgroundColor: AppThemeNotifier.isWhite ? Colors.white : const Color(0xFF120404)
// For card text: color: AppThemeNotifier.isWhite ? EleghartColors.accentDark : Colors.white
// For subtext: color: AppThemeNotifier.isWhite ? EleghartColors.accentDark.withOpacity(0.5) : Colors.white38
```

## New Theme-Sensitive Widget Checklist
- Wrap in `ValueListenableBuilder<bool>(valueListenable: AppThemeNotifier.instance, builder: (_, isWhite, __) => ...)` OR use `addListener` on parent State
- Use `isWhite ? lightColor : darkColor` pattern

## ID Generation
```dart
import 'package:uuid/uuid.dart';
final id = const Uuid().v4();
```

## Loading Data Pattern
```dart
Future<void> _loadData() async {
  final groups = await StorageService.loadGroups();
  final expenses = await StorageService.loadExpenses();
  if (!mounted) return;
  setState(() { _groups = groups; _expenses = expenses; _loading = false; });
}
```

## Saving Data Pattern
```dart
await StorageService.saveExpenses(_expenses);
await StorageService.saveGroups(_groups);
// Then setState if UI needs update
```

## Navigation Pattern
```dart
// Push and await result
final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => Screen(...)));
if (result == true) _loadData(); // refresh if changed

// Return data
Navigator.pop(context, someData);
```

## Naming
- Files: `snake_case.dart`
- Classes/Widgets: `PascalCase`
- Private State methods/fields: `_camelCase`
- SharedPreferences keys: `snake_case_v{N}` (include version suffix)
