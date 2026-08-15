import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/splitwise_models.dart';
import '../utils/data_sync.dart';

class SplitwiseStorageService {
  static const String _groupsKey = 'splitwise_module_groups_v1';
  static const String _expensesKey = 'splitwise_module_expenses_v1';

  // ─── Splitwise Groups ──────────────────────────────────────────────────────

  static Future<List<SplitwiseGroupModel>> loadGroups() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_groupsKey) ?? [];
    return rawList
        .map((raw) => SplitwiseGroupModel.fromJson(jsonDecode(raw)))
        .toList();
  }

  static Future<void> saveGroups(List<SplitwiseGroupModel> groups) async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = groups.map((g) => jsonEncode(g.toJson())).toList();
    await prefs.setStringList(_groupsKey, rawList);
    DataSyncNotifier.notifyDataChanged();
  }

  static Future<void> addGroup(SplitwiseGroupModel group) async {
    final list = await loadGroups();
    list.insert(0, group);
    await saveGroups(list);
  }

  static Future<void> updateGroup(SplitwiseGroupModel group) async {
    final list = await loadGroups();
    final idx = list.indexWhere((g) => g.id == group.id);
    if (idx != -1) {
      list[idx] = group;
      await saveGroups(list);
    }
  }

  static Future<void> deleteGroup(String groupId) async {
    final groups = await loadGroups();
    groups.removeWhere((g) => g.id == groupId);
    await saveGroups(groups);

    final expenses = await loadExpenses();
    expenses.removeWhere((e) => e.splitwiseGroupId == groupId);
    await saveExpenses(expenses);
  }

  // ─── Splitwise Expenses ────────────────────────────────────────────────────

  static Future<List<SplitwiseExpenseModel>> loadExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_expensesKey) ?? [];
    return rawList
        .map((raw) => SplitwiseExpenseModel.fromJson(jsonDecode(raw)))
        .toList();
  }

  static Future<void> saveExpenses(List<SplitwiseExpenseModel> list) async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = list.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_expensesKey, rawList);
    DataSyncNotifier.notifyDataChanged();
  }

  static Future<void> addExpense(SplitwiseExpenseModel expense) async {
    final list = await loadExpenses();
    list.insert(0, expense);
    await saveExpenses(list);
  }

  static Future<void> deleteExpense(String expenseId) async {
    final list = await loadExpenses();
    list.removeWhere((e) => e.id == expenseId);
    await saveExpenses(list);
  }

  /// Sanitizes expenses for a group to ensure 'equal' splits are evenly divided across all members
  static Future<void> sanitizeExpensesForGroup(SplitwiseGroupModel group) async {
    if (group.members.length <= 1) return;

    final allExpenses = await loadExpenses();
    bool modified = false;

    for (int i = 0; i < allExpenses.length; i++) {
      final e = allExpenses[i];
      if (e.splitwiseGroupId == group.id && e.splitType == 'equal') {
        // If distribution is empty or has fewer members than the group
        if (e.distribution.isEmpty || e.distribution.length < group.members.length) {
          final Map<String, double> newDist = {};
          final share = e.amount / group.members.length;
          for (final m in group.members) {
            newDist[m] = share;
          }
          allExpenses[i] = SplitwiseExpenseModel(
            id: e.id,
            splitwiseGroupId: e.splitwiseGroupId,
            title: e.title,
            amount: e.amount,
            date: e.date,
            splitType: e.splitType,
            paidBy: e.paidBy,
            distribution: newDist,
          );
          modified = true;
        }
      }
    }

    if (modified) {
      await saveExpenses(allExpenses);
    }
  }
}
