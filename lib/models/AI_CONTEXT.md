# lib/models/ — AI Context

## Files
- `group_model.dart` — GroupModel class
- `expense_model.dart` — ExpenseModel class

## GroupModel Fields
```
id: String          — UUID, never changes after creation
name: String        — display name
imagePath: String?  — local file path for group cover image
categories: List<String>  — tags like ["Trips", "Food"]
```

## ExpenseModel Fields
```
id: String          — UUID
groupId: String     — FK to GroupModel.id
amount: double      — positive value always
description: String — user-entered note
categories: List<String>  — per-expense category tags
date: DateTime
imagePath: String?  — receipt photo local path
type: String        — 'debit' | 'credit' (default: 'debit')
```
Getters: `isDebit → bool`, `isCredit → bool`

## Serialization
Both models have `toJson()` and `fromJson(Map)` factory.
Stored via `StorageService` — see `lib/services/AI_CONTEXT.md`.

## IMPORTANT
- `type` field defaults to `'debit'` for backward compatibility
- Old records from before type was added have no `type` key → treated as `'debit'`
- Do NOT rename fields — breaks JSON deserialization of existing user data
