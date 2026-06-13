import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/wealth_models.dart';
import 'database_service.dart';

class WealthRepository {
  static const _uuid = Uuid();

  // ─── Goals ────────────────────────────────────────────────────────────────

  static Future<List<WealthGoal>> loadGoals() async {
    final db = await DatabaseService.database;
    final rows =
        await db.query('wealth_goals', orderBy: 'created_at DESC');
    return rows.map(WealthGoal.fromMap).toList();
  }

  static Future<void> insertGoal(WealthGoal goal) async {
    final db = await DatabaseService.database;
    await db.insert('wealth_goals', goal.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> updateGoal(WealthGoal goal) async {
    final db = await DatabaseService.database;
    await db.update(
      'wealth_goals',
      goal.toMap(),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  static Future<void> deleteGoal(String id) async {
    final db = await DatabaseService.database;
    await db.transaction((txn) async {
      await txn.delete('wealth_contributions',
          where: 'goal_id = ?', whereArgs: [id]);
      await txn
          .delete('wealth_goals', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ─── Contributions ────────────────────────────────────────────────────────

  static Future<List<WealthContribution>> loadContributions(
      String goalId) async {
    final db = await DatabaseService.database;
    final rows = await db.query(
      'wealth_contributions',
      where: 'goal_id = ?',
      whereArgs: [goalId],
      orderBy: 'contribution_date DESC',
    );
    return rows.map(WealthContribution.fromMap).toList();
  }

  static Future<WealthGoal> addContribution({
    required WealthGoal goal,
    required double amount,
    required DateTime date,
    String? notes,
  }) async {
    final db = await DatabaseService.database;
    final contribution = WealthContribution(
      id: _uuid.v4(),
      goalId: goal.id,
      amount: amount,
      contributionDate: date,
      notes: notes,
      createdAt: DateTime.now(),
    );
    final newAmount =
        (goal.currentAmount + amount).clamp(0.0, double.infinity);
    final updatedGoal = goal.copyWith(currentAmount: newAmount);
    await db.transaction((txn) async {
      await txn.insert('wealth_contributions', contribution.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.update(
        'wealth_goals',
        {'current_amount': newAmount},
        where: 'id = ?',
        whereArgs: [goal.id],
      );
    });
    return updatedGoal;
  }

  static Future<WealthGoal> deleteContribution(
      WealthContribution c, WealthGoal goal) async {
    final db = await DatabaseService.database;
    final newAmount =
        (goal.currentAmount - c.amount).clamp(0.0, double.infinity);
    await db.transaction((txn) async {
      await txn.delete('wealth_contributions',
          where: 'id = ?', whereArgs: [c.id]);
      await txn.update(
        'wealth_goals',
        {'current_amount': newAmount},
        where: 'id = ?',
        whereArgs: [goal.id],
      );
    });
    return goal.copyWith(currentAmount: newAmount);
  }

  static String generateId() => _uuid.v4();
}
