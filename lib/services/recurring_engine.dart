import 'package:uuid/uuid.dart';

import '../models/expense_model.dart';
import '../models/recurring_expense_model.dart';
import '../models/emi_model.dart';
import 'storage_service.dart';

/// Runs on app launch. Checks recurring schedules + EMIs and
/// auto-creates ExpenseModel entries for any overdue periods.
class RecurringEngine {
  static Future<void> run() async {
    await Future.wait([_processRecurring(), _processEmis()]);
  }

  // ─── Recurring ─────────────────────────────────────────────────────────────

  static Future<void> _processRecurring() async {
    final recurring = await StorageService.loadRecurring();
    final expenses = await StorageService.loadExpenses();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    bool changed = false;
    final updatedRecurring = <RecurringExpenseModel>[];

    for (final r in recurring) {
      if (!r.isActive) {
        updatedRecurring.add(r);
        continue;
      }
      if (r.endDate != null && today.isAfter(r.endDate!)) {
        updatedRecurring.add(r.copyWith(isActive: false));
        changed = true;
        continue;
      }

      var current = r.lastGeneratedDate ?? r.startDate.subtract(const Duration(days: 1));
      DateTime? latestGenerated;

      // Generate all dues from last generated up to today
      while (true) {
        final next = r.nextDueDate(current);
        final dueDay = DateTime(next.year, next.month, next.day);
        
        if (dueDay.isAfter(today)) break;
        if (r.endDate != null) {
          final endDay = DateTime(r.endDate!.year, r.endDate!.month, r.endDate!.day);
          if (dueDay.isAfter(endDay)) break;
        }

        // Avoid duplicate: check if we already generated for this dueDay
        final alreadyExists = expenses.any((e) =>
            e.description.contains(r.name) &&
            DateTime(e.date.year, e.date.month, e.date.day) == dueDay);

        if (!alreadyExists) {
          expenses.add(ExpenseModel(
            id: const Uuid().v4(),
            groupId: r.groupId,
            amount: r.amount,
            description: '${r.name} · ${_monthYear(next)}',
            categories: List.from(r.categories),
            date: next,
            type: 'debit',
          ));
          changed = true;
        }

        latestGenerated = next;
        current = next;
      }

      updatedRecurring.add(latestGenerated != null
          ? r.copyWith(lastGeneratedDate: latestGenerated)
          : r);
    }

    if (changed) {
      await Future.wait([
        StorageService.saveExpenses(expenses),
        StorageService.saveRecurring(updatedRecurring),
      ]);
    }
  }

  // ─── EMI ───────────────────────────────────────────────────────────────────

  static Future<void> _processEmis() async {
    final emis = await StorageService.loadEmis();
    final expenses = await StorageService.loadExpenses();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    bool changed = false;
    final updatedEmis = <EmiModel>[];

    for (final emi in emis) {
      if (emi.isCompleted) {
        updatedEmis.add(emi);
        continue;
      }

      var completed = emi.completed;
      DateTime? latestGenerated;

      // Each instalment is due on startDate + N months
      while (completed < emi.tenure) {
        final dueDate = DateTime(
            emi.startDate.year, emi.startDate.month + completed, emi.startDate.day);
        final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
        if (dueDay.isAfter(today)) break;

        final instalment = completed + 1;
        final alreadyExists = expenses.any((e) =>
            e.description.contains(emi.productName) &&
            e.description.contains('$instalment/${emi.tenure}'));

        if (!alreadyExists) {
          expenses.add(ExpenseModel(
            id: const Uuid().v4(),
            groupId: emi.groupId,
            amount: emi.amount,
            description: 'EMI · ${emi.productName} · $instalment/${emi.tenure}',
            categories: List.from(emi.categories),
            date: dueDate,
            type: 'debit',
          ));
          changed = true;
        }
        completed++;
        latestGenerated = dueDate;
      }

      updatedEmis.add(emi.copyWith(
        completed: completed,
        lastGeneratedDate: latestGenerated ?? emi.lastGeneratedDate,
      ));
    }

    if (changed) {
      await Future.wait([
        StorageService.saveExpenses(expenses),
        StorageService.saveEmis(updatedEmis),
      ]);
    }
  }

  static String _monthYear(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.year}';
  }
}
