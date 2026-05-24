# lib/services/ — AI Context

## Files
- `storage_service.dart` — All local persistence (47 lines, all static methods)
- `pdf_export_service.dart` — PDF generation (~18KB, complex layout, rarely modified)

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
