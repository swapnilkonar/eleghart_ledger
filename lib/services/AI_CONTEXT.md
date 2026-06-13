# lib/services/ — AI Context

## Files
- `storage_service.dart` — All local persistence (47 lines, all static methods)
- `pdf_export_service.dart` — PDF generation (~18KB, complex layout, rarely modified)
- `ai_extraction_service.dart` — On-device OCR + smart receipt parsing (no API key, no internet)
- `database_service.dart` — SQLite singleton for Wealth Journey (v2, wealth_goals + wealth_contributions)
- `wealth_repository.dart` — All Wealth Journey DB CRUD (goals + contributions)
- `wealth_service.dart` — Pure calculations: health, monthly required, expected, gap, format

## StorageService — Complete API
```dart
// Groups
StorageService.loadGroups()                    → Future<List<GroupModel>>
StorageService.saveGroups(List<GroupModel>)    → Future<void>

// Expenses
StorageService.loadExpenses()                  → Future<List<ExpenseModel>>
StorageService.saveExpenses(List<ExpenseModel>) → Future<void>

// Category Images (Map<categoryName, localFilePath>)
StorageService.loadCategoryImages()            → Future<Map<String,String>>
StorageService.saveCategoryImages(Map)         → Future<void>
```

## SharedPreferences Keys Used
| Key | Method | Format |
|-----|--------|--------|
| `groups_v2` | StringList | each item = JSON string of GroupModel |
| `expenses_v2` | StringList | each item = JSON string of ExpenseModel |
| `category_images_v1` | String | single JSON object string |

## PdfExportService
- Entry point: `PdfExportService.generateAndSharePdf(GroupModel, List<ExpenseModel>)`
- Large file — only open if changing PDF layout/columns/styling
- Uses `pdf` package for document creation, `share_plus` for sharing, `open_filex` for opening

## AIExtractionService — On-Device OCR
```dart
// No API key, no internet — uses google_mlkit_text_recognition

// Extract from image (JPEG/PNG/WEBP):
AIExtractionService.extractFromImage(imageFile: File) → Future<List<ExtractedItem>>

// Extract from PDF (currently throws UnsupportedError — PDF OCR not yet supported):
AIExtractionService.extractFromPdf(pdfFile: File) → Future<List<ExtractedItem>>
```

### _ReceiptParser (private, used by AIExtractionService)
```
Input:  Raw OCR text string from TextRecognizer
Output: List<ExtractedItem>

Logic:
1. _merchantName(lines)  → first non-numeric line of length ≥3
2. _extractDate(text)    → regex: DD/MM/YY, MM/DD/YYYY, YYYY-MM-DD
3. _extractLineItems()   → lines with both text AND amount; skips GST/tax/total/savings rows
                            returns [] if >10 items found (noise protection)
4. _bestTotal()          → prefers line containing 'total'/'grand total'; fallback = largest amount
5. _inferCategory()      → keyword matching across 7 categories:
   Food & Dining: restaurant, cafe, zomato, swiggy, blinkit, dhaba, bakery, meal...
   Travel:        uber, ola, rapido, irctc, flight, airline, metro, bus, toll...
   Fuel:          petrol, diesel, cng, hp, bpcl, iocl, pump...
   Shopping:      amazon, flipkart, myntra, dmart, reliance, big bazaar, store...
   Bills:         electricity, airtel, jio, vi, bsnl, recharge, insurance, emi...
   Health:        hospital, clinic, pharmacy, medicine, apollo, diagnostic...
   Entertainment: movie, pvr, inox, netflix, spotify, bookmyshow, concert...
   Others:        fallback
```

### ExtractedItem (data class, defined in extracted_expenses_screen.dart)
```dart
class ExtractedItem {
  final String id;           // UUID
  final String description;  // merchant / item name
  final double amount;
  final String category;     // one of the 8 valid categories
  final DateTime date;
}
```

## DatabaseService — SQLite Singleton
```dart
// DB file: eleghart_ledger.db  |  Version: 2
// Wealth tables added in v2 via onUpgrade (existing users safe)
await DatabaseService.database  // → Future<Database> (singleton)
// Tables: wealth_goals, wealth_contributions (+ all legacy tables)
```

## WealthRepository — Complete API
```dart
// Goals
WealthRepository.loadGoals()                        → Future<List<WealthGoal>>  // DESC created_at
WealthRepository.insertGoal(WealthGoal)             → Future<void>
WealthRepository.updateGoal(WealthGoal)             → Future<void>              // preserves currentAmount
WealthRepository.deleteGoal(String id)              → Future<void>              // cascades contributions

// Contributions
WealthRepository.loadContributions(String goalId)   → Future<List<WealthContribution>> // DESC date
WealthRepository.addContribution({                  → Future<WealthGoal>        // returns updated goal
  goal, amount, date, notes})
// ⚠️ amount: positive=credit, negative=debit. currentAmount clamped to 0.
WealthRepository.deleteContribution(c, goal)        → Future<WealthGoal>        // reverses amount

WealthRepository.generateId()                       → String (UUID v4)
```

## WealthService — Calculation API
```dart
WealthService.calculateHealth(goal)        → GoalHealth   // uses expectedSaved()
WealthService.calculateMonthlyRequired(g)  → double       // remaining ÷ monthsLeft
WealthService.elapsedMonths(goal)          → int
WealthService.remainingMonths(goal)        → int
WealthService.totalMonths(goal)            → int (min 1)
WealthService.expectedSaved(goal)          → double       // month-based, min 1 month → never ₹0
WealthService.gap(goal)                    → double       // max(0, expected - actual)
WealthService.coachMessage(goal)           → String
WealthService.formatAmount(v)              → String       // ₹42, ₹1.2K, ₹1.5L, ₹1.2Cr
WealthService.formatAmountFull(v)          → String       // ₹1.20L, ₹1.20Cr

// GoalHealth enum: ahead | onTrack | slightlyBehind | critical
// Health thresholds: actual/expected × 100 → ≥110=ahead, ≥95=onTrack, ≥75=slightlyBehind, else=critical
```
