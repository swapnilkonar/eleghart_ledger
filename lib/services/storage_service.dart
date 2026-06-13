import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/group_model.dart';
import '../models/expense_model.dart';
import '../models/recurring_expense_model.dart';
import '../models/emi_model.dart';
import '../models/person_model.dart';
import '../models/ledger_transaction_model.dart';
import 'database_service.dart';

class StorageService {
  static const _categoryImagesKey = 'category_images_v1';
  static const _globalCategoriesKey = 'global_categories_v1';

  // ─── Settings (stay in SharedPreferences) ─────────────────────────────────

  static Future<List<String>> loadGlobalCategories() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_globalCategoriesKey) ?? [];
  }

  static Future<void> saveGlobalCategories(List<String> categories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_globalCategoriesKey, categories);
  }

  static Future<Map<String, String>> loadCategoryImages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_categoryImagesKey) ?? '{}';
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.cast<String, String>();
  }

  static Future<void> saveCategoryImages(Map<String, String> images) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_categoryImagesKey, jsonEncode(images));
  }

  // ─── Data (delegated to SQLite) ───────────────────────────────────────────

  static Future<List<GroupModel>> loadGroups() => DatabaseService.loadGroups();
  static Future<void> saveGroups(List<GroupModel> groups) =>
      DatabaseService.saveGroups(groups);

  static Future<List<ExpenseModel>> loadExpenses() =>
      DatabaseService.loadExpenses();
  static Future<void> saveExpenses(List<ExpenseModel> expenses) =>
      DatabaseService.saveExpenses(expenses);

  static Future<List<RecurringExpenseModel>> loadRecurring() =>
      DatabaseService.loadRecurring();
  static Future<void> saveRecurring(List<RecurringExpenseModel> list) =>
      DatabaseService.saveRecurring(list);

  static Future<List<EmiModel>> loadEmis() => DatabaseService.loadEmis();
  static Future<void> saveEmis(List<EmiModel> list) =>
      DatabaseService.saveEmis(list);

  static Future<List<PersonModel>> loadPersons() =>
      DatabaseService.loadPersons();
  static Future<void> savePersons(List<PersonModel> list) =>
      DatabaseService.savePersons(list);

  static Future<List<LedgerTransactionModel>> loadUdhaarTransactions() =>
      DatabaseService.loadUdhaarTransactions();
  static Future<void> saveUdhaarTransactions(
          List<LedgerTransactionModel> list) =>
      DatabaseService.saveUdhaarTransactions(list);
}
