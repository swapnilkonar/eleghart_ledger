# Glossary — Eleghart Ledger

## Domain Terms
| Term | Meaning |
|------|---------|
| **Group** | A named container for expenses (e.g. "Goa Trip", "Roommates"). Has id, name, imagePath, categories. |
| **Expense** | A single financial transaction inside a Group. Has amount, type(debit/credit), description, date, receipt. |
| **Debit** | Money spent / outflow. `expense.type == 'debit'`, `expense.isDebit == true` |
| **Credit** | Money received / inflow. `expense.type == 'credit'`, `expense.isCredit == true` |
| **Net Balance** | `totalCredit - totalDebit` across all expenses. Positive = surplus, Negative = deficit. |
| **Category** | A tag on a Group (e.g. "Trips", "Food"). Groups can have multiple categories. Also used in `categories` field of ExpenseModel for per-expense categorization. |
| **Date Filter** | Global filter controlled by `DateFilter.notifier`. Options: currentMonth, lastMonth, allTime, custom month. |
| **White Theme** | Light background mode. `AppThemeNotifier.isWhite == true`. Uses `background_theme_white.png`. |
| **Dark Theme** | Default dark background mode. `AppThemeNotifier.isWhite == false`. Uses `background_theme_top_glow.png`. |
| **ThemedBackground** | Reusable widget that auto-swaps background images based on theme. Used in every screen. |
| **ProfileSheet** | Bottom sheet modal opened from HomeDashboard app bar. Contains name/avatar/PIN/theme settings. |
| **Sparkline** | Mini line chart shown on group cards. Built with `fl_chart`. |
| **Receipt** | Optional photo attached to an expense. Stored as local file path in `expense.imagePath`. |
| **PIN** | 4-digit numeric app lock. Stored as plain string in SharedPreferences key `user_pin`. |

## Code Abbreviations
| Abbreviation | Meaning |
|---|---|
| `prefs` | SharedPreferences instance |
| `_dataChanged` | bool flag in GroupDetailScreen — tells parent to reload |
| `_loading` | bool state field — shows CircularProgressIndicator while true |
| `balPositive` | `balance >= 0` — used for color-coding balance text |
| `isWhite` | shorthand for `AppThemeNotifier.isWhite` |
| `sparkColor` | color of sparkline in group card, derived from status |
| `catImages` | Map<String, String> — category name → image file path |
| `v2` suffix | storage key version (e.g. `groups_v2`) — increment if schema changes |
