import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/group_model.dart';
import '../models/expense_model.dart';

class StorageService {
  static const _groupsKey = 'groups_v2';
  static const _expensesKey = 'expenses_v2';
  static const _categoryImagesKey = 'category_images_v1';

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
}
