# lib/theme/ — AI Context

## Files
- `eleghart_colors.dart` — All app colors as static const

## EleghartColors — Complete Color Table
```dart
// Backgrounds
EleghartColors.bgLight     = Color(0xFFE5E7EB)   // light grey
EleghartColors.metalDark   = Color(0xFF2A2F38)   // dark steel
EleghartColors.metalLight  = Color(0xFF3A3F4B)   // lighter steel

// Accent Red (primary brand color)
EleghartColors.accentDark  = Color(0xFF8E1D1D)   // deep red — use for white-theme text
EleghartColors.accentMid   = Color(0xFFB32626)   // mid red
EleghartColors.accentLight = Color(0xFFC73535)   // bright red

// Text
EleghartColors.textPrimary   = Color(0xFF0F172A)  // near-black
EleghartColors.textSecondary = Color(0xFF6B7280)  // grey
EleghartColors.textHint      = Color(0xFF9CA3AF)  // light grey

// UI
EleghartColors.inputBg  = Color(0xFFFFFFFF)
EleghartColors.cardBg   = Color(0xFFFFFFFF)
EleghartColors.divider  = Color(0xFFE5E7EB)
```

## White Theme Color Guide
When `AppThemeNotifier.isWhite == true`, replace:
| Dark color | White theme replacement |
|---|---|
| `Colors.white` (text) | `EleghartColors.accentDark` |
| `Colors.white54` | `EleghartColors.accentDark.withOpacity(0.55)` |
| `Colors.white38` | `EleghartColors.accentDark.withOpacity(0.45)` |
| `Colors.white70` | `Colors.black54` (on light card) |
| `Colors.white24` | `Colors.black26` |
| `Color(0xFF0E0505)` card bg | `Color(0xFFFFF5F5)` (light blush) |
| `Color(0xFF120505)` card bg | `Color(0xFFFFF0F0)` (light rose) |
| `Color(0xFF1A0505)` placeholder | `Color(0xFFFFE8E8)` (light pink) |
| `Colors.white.withOpacity(0.06)` | `Color(0xFFFFECEC)` |
| `Colors.white.withOpacity(0.18)` | `EleghartColors.accentDark.withOpacity(0.08)` |
