import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/group_model.dart';
import '../models/expense_model.dart';

class StorageService {
  static const _groupsKey = 'groups_v2';
  static const _expensesKey = 'expenses_v2';

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
