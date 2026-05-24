# lib/widgets/ — AI Context

## Files
- `themed_background.dart` — Theme-reactive background (core widget)
- `date_filter_pill.dart` — Horizontal filter pill row (~14KB)
- `empty_state.dart` — Generic empty state display
- `group_card.dart` — Unused/legacy group card widget

## ThemedBackground (themed_background.dart, ~28 lines)
```dart
// Constructor
ThemedBackground({double darkOverlayOpacity = 0.65})

// Usage (always inside Positioned.fill)
Positioned.fill(child: ThemedBackground(darkOverlayOpacity: 0.72))

// Behavior
// - Listens to AppThemeNotifier.instance via ValueListenableBuilder
// - White theme: shows background_theme_white.png, NO overlay
// - Dark theme: shows background_theme_top_glow.png + black overlay at darkOverlayOpacity
```
Recommended opacity values:
- 0.25 → PIN screens (logo visible)
- 0.40 → Welcome/Onboarding
- 0.65 → HomeDashboard
- 0.70-0.72 → All detail screens

## DateFilterPill (date_filter_pill.dart, ~14KB)
- Self-contained widget. Drop in anywhere.
- Drives `DateFilter.notifier` — no props needed.
- Shows current filter label + allows month picker.
- Usage: `const DateFilterPill()`

## empty_state.dart
- Generic empty state with icon + message
- Rarely used directly; screens implement their own empty states

## group_card.dart
- Legacy widget — screens use inline `_buildGroupCard()` method instead
- Do not modify unless refactoring card UI
