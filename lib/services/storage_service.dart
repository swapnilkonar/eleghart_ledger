import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/group_model.dart';
import '../models/expense_model.dart';
import '../models/recurring_expense_model.dart';
import '../models/emi_model.dart';
import '../models/person_model.dart';
import '../models/ledger_transaction_model.dart';

class StorageService {
  static const _groupsKey = 'groups_v2';
  static const _expensesKey = 'expenses_v2';
  static const _categoryImagesKey = 'category_images_v1';
  static const _globalCategoriesKey = 'global_categories_v1';
  static const _recurringKey = 'recurring_v1';
  static const _emiKey = 'emi_v1';
  static const _udhaarPersonsKey = 'udhaar_persons_v1';
  static const _udhaarTransactionsKey = 'udhaar_transactions_v1';

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

  static Future<List<GroupModel>> loadGroups() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_groupsKey) ?? [];
    return raw.map((e) => GroupModel.fromJson(jsonDecode(e))).toList();
  }

  static Future<void> saveGroups(List<GroupModel> groups) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = groups.map((g) => jsonEncode(g.toJson())).toList();
    await prefs.setStringList(_groupsKey, raw);
  }

  static Future<List<ExpenseModel>> loadExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_expensesKey) ?? [];
    return raw.map((e) => ExpenseModel.fromJson(jsonDecode(e))).toList();
  }

  static Future<void> saveExpenses(List<ExpenseModel> expenses) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = expenses.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_expensesKey, raw);
  }

  // ─── Recurring Expenses ───────────────────────────────────────────────────

  static Future<List<RecurringExpenseModel>> loadRecurring() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_recurringKey) ?? [];
    return raw
        .map((e) => RecurringExpenseModel.fromJson(jsonDecode(e)))
        .toList();
  }

  static Future<void> saveRecurring(
      List<RecurringExpenseModel> list) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = list.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList(_recurringKey, raw);
  }

  // ─── EMI ─────────────────────────────────────────────────────────────────

  static Future<List<EmiModel>> loadEmis() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_emiKey) ?? [];
    return raw.map((e) => EmiModel.fromJson(jsonDecode(e))).toList();
  }

  static Future<void> saveEmis(List<EmiModel> list) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = list.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_emiKey, raw);
  }

  // ─── Udhaar – Persons ─────────────────────────────────────────────────────

  static Future<List<PersonModel>> loadPersons() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_udhaarPersonsKey) ?? [];
    return raw.map((e) => PersonModel.fromJson(jsonDecode(e))).toList();
  }

  static Future<void> savePersons(List<PersonModel> list) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = list.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_udhaarPersonsKey, raw);
  }

  // ─── Udhaar – Transactions ────────────────────────────────────────────────

  static Future<List<LedgerTransactionModel>> loadUdhaarTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_udhaarTransactionsKey) ?? [];
    return raw
        .map((e) => LedgerTransactionModel.fromJson(jsonDecode(e)))
        .toList();
  }

  static Future<void> saveUdhaarTransactions(
      List<LedgerTransactionModel> list) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = list.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_udhaarTransactionsKey, raw);
  }
}
