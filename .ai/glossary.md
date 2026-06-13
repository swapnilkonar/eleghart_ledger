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

| **WealthGoal** | A savings goal with name, type, target amount, target date, and current progress. Stored in SQLite `wealth_goals`. |
| **WealthContribution** | A single credit or debit entry against a goal. Positive = credit (money added), Negative = debit (money withdrawn). Stored in `wealth_contributions`. |
| **GoalType** | Enum: emergencyFund, house, car, marriage, retirement, vacation, education, custom. Each has label/icon/color. |
| **GoalHealth** | Enum: ahead, onTrack, slightlyBehind, critical. Derived by comparing currentAmount to expectedSaved. |
| **Credit (Wealth)** | Money deposited into a goal. Stored as positive amount. Green ↑ arrow in UI. |
| **Debit (Wealth)** | Money withdrawn from a goal for personal use. Stored as negative amount. Red ↓ arrow in UI. currentAmount clamped to 0. |
| **expectedSaved** | `WealthService.expectedSaved()` — how much should have been saved by now. Month-based, minimum 1 month elapsed so always non-zero. |
| **gap** | `WealthService.gap()` — how far behind the goal is: `max(0, expectedSaved - currentAmount)`. |
| **startAmount** | The savings amount the user already had when they created the goal. Locked after creation. |
| **currentAmount** | Running total: `startAmount + sum(contributions)`. Updated atomically in DB with every addContribution/deleteContribution. |
| **Wealth Snapshot** | Small card on HomeDashboard Tab 0 showing total goals + avg progress. Opens WealthDashboardScreen. |

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
| `signedAmt` | `isCredit ? amt : -amt` — used before calling `WealthRepository.addContribution` |
| `_isEditing` | getter in `CreateGoalScreen`: `widget.goal != null` |
| `_goal` | mutable `WealthGoal` state in `GoalDetailScreen` — updated on contribution/edit, returned via PopScope |
