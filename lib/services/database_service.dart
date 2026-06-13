import 'dart:convert';

import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/emi_model.dart';
import '../models/expense_model.dart';
import '../models/group_model.dart';
import '../models/ledger_transaction_model.dart';
import '../models/person_model.dart';
import '../models/recurring_expense_model.dart';

class DatabaseService {
  static Database? _db;
  static const _dbVersion = 2;
  static const _migrationKey = 'db_migrated_v1';

  static Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    final dbPath = join(await getDatabasesPath(), 'eleghart_ledger.db');
    return openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createWealthTables(db);
    }
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE groups (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        image_path TEXT,
        categories TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        group_id TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT NOT NULL,
        categories TEXT NOT NULL,
        date TEXT NOT NULL,
        image_path TEXT,
        type TEXT NOT NULL DEFAULT 'debit',
        distribution TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE recurring_expenses (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        frequency TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT,
        group_id TEXT NOT NULL,
        categories TEXT NOT NULL,
        description TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        last_generated_date TEXT,
        distribution TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE emis (
        id TEXT PRIMARY KEY,
        product_name TEXT NOT NULL,
        amount REAL NOT NULL,
        tenure INTEGER NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        start_date TEXT NOT NULL,
        group_id TEXT NOT NULL,
        categories TEXT NOT NULL,
        description TEXT NOT NULL,
        last_generated_date TEXT,
        distribution TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE persons (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        photo_path TEXT,
        phone TEXT,
        address TEXT,
        grp TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE ledger_transactions (
        id TEXT PRIMARY KEY,
        person_id TEXT NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT NOT NULL,
        category TEXT,
        attachment_path TEXT,
        notes TEXT,
        transaction_date TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await _createWealthTables(db);
  }

  static Future<void> _createWealthTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS wealth_goals (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        goal_type TEXT NOT NULL,
        target_amount REAL NOT NULL,
        current_amount REAL NOT NULL DEFAULT 0,
        start_amount REAL NOT NULL DEFAULT 0,
        target_date TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS wealth_contributions (
        id TEXT PRIMARY KEY,
        goal_id TEXT NOT NULL,
        amount REAL NOT NULL,
        contribution_date TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (goal_id) REFERENCES wealth_goals(id)
      )
    ''');
  }

  // ─── Migration from SharedPreferences ─────────────────────────────────────

  static Future<void> migrateFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migrationKey) == true) return;

    final db = await database;

    for (final raw in prefs.getStringList('groups_v2') ?? []) {
      try {
        await db.insert('groups', _groupToMap(GroupModel.fromJson(jsonDecode(raw))),
            conflictAlgorithm: ConflictAlgorithm.ignore);
      } catch (_) {}
    }
    for (final raw in prefs.getStringList('expenses_v2') ?? []) {
      try {
        await db.insert('expenses', _expenseToMap(ExpenseModel.fromJson(jsonDecode(raw))),
            conflictAlgorithm: ConflictAlgorithm.ignore);
      } catch (_) {}
    }
    for (final raw in prefs.getStringList('recurring_v1') ?? []) {
      try {
        await db.insert('recurring_expenses',
            _recurringToMap(RecurringExpenseModel.fromJson(jsonDecode(raw))),
            conflictAlgorithm: ConflictAlgorithm.ignore);
      } catch (_) {}
    }
    for (final raw in prefs.getStringList('emi_v1') ?? []) {
      try {
        await db.insert('emis', _emiToMap(EmiModel.fromJson(jsonDecode(raw))),
            conflictAlgorithm: ConflictAlgorithm.ignore);
      } catch (_) {}
    }
    for (final raw in prefs.getStringList('udhaar_persons_v1') ?? []) {
      try {
        await db.insert('persons', _personToMap(PersonModel.fromJson(jsonDecode(raw))),
            conflictAlgorithm: ConflictAlgorithm.ignore);
      } catch (_) {}
    }
    for (final raw in prefs.getStringList('udhaar_transactions_v1') ?? []) {
      try {
        await db.insert('ledger_transactions',
            _txToMap(LedgerTransactionModel.fromJson(jsonDecode(raw))),
            conflictAlgorithm: ConflictAlgorithm.ignore);
      } catch (_) {}
    }

    await prefs.setBool(_migrationKey, true);
  }

  // ─── Groups ───────────────────────────────────────────────────────────────

  static Future<List<GroupModel>> loadGroups() async {
    final rows = await (await database).query('groups');
    return rows.map(_mapToGroup).toList();
  }

  static Future<void> saveGroups(List<GroupModel> groups) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('groups');
      for (final g in groups) {
        await txn.insert('groups', _groupToMap(g));
      }
    });
  }

  // ─── Expenses ─────────────────────────────────────────────────────────────

  static Future<List<ExpenseModel>> loadExpenses() async {
    final rows = await (await database).query('expenses', orderBy: 'date DESC');
    return rows.map(_mapToExpense).toList();
  }

  static Future<void> saveExpenses(List<ExpenseModel> expenses) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('expenses');
      for (final e in expenses) {
        await txn.insert('expenses', _expenseToMap(e));
      }
    });
  }

  // ─── Recurring ────────────────────────────────────────────────────────────

  static Future<List<RecurringExpenseModel>> loadRecurring() async {
    final rows = await (await database).query('recurring_expenses');
    return rows.map(_mapToRecurring).toList();
  }

  static Future<void> saveRecurring(List<RecurringExpenseModel> list) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('recurring_expenses');
      for (final r in list) {
        await txn.insert('recurring_expenses', _recurringToMap(r));
      }
    });
  }

  // ─── EMIs ─────────────────────────────────────────────────────────────────

  static Future<List<EmiModel>> loadEmis() async {
    final rows = await (await database).query('emis');
    return rows.map(_mapToEmi).toList();
  }

  static Future<void> saveEmis(List<EmiModel> list) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('emis');
      for (final e in list) {
        await txn.insert('emis', _emiToMap(e));
      }
    });
  }

  // ─── Persons ──────────────────────────────────────────────────────────────

  static Future<List<PersonModel>> loadPersons() async {
    final rows = await (await database).query('persons', orderBy: 'created_at DESC');
    return rows.map(_mapToPerson).toList();
  }

  static Future<void> savePersons(List<PersonModel> list) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('persons');
      for (final p in list) {
        await txn.insert('persons', _personToMap(p));
      }
    });
  }

  // ─── Ledger Transactions ──────────────────────────────────────────────────

  static Future<List<LedgerTransactionModel>> loadUdhaarTransactions() async {
    final rows = await (await database)
        .query('ledger_transactions', orderBy: 'transaction_date DESC');
    return rows.map(_mapToTx).toList();
  }

  static Future<void> saveUdhaarTransactions(
      List<LedgerTransactionModel> list) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('ledger_transactions');
      for (final t in list) {
        await txn.insert('ledger_transactions', _txToMap(t));
      }
    });
  }

  // ─── Converters ───────────────────────────────────────────────────────────

  static Map<String, dynamic> _groupToMap(GroupModel g) => {
        'id': g.id,
        'name': g.name,
        'image_path': g.imagePath,
        'categories': jsonEncode(g.categories),
      };

  static GroupModel _mapToGroup(Map<String, dynamic> m) => GroupModel(
        id: m['id'] as String,
        name: m['name'] as String,
        imagePath: m['image_path'] as String?,
        categories:
            List<String>.from(jsonDecode(m['categories'] as String)),
      );

  static Map<String, dynamic> _expenseToMap(ExpenseModel e) => {
        'id': e.id,
        'group_id': e.groupId,
        'amount': e.amount,
        'description': e.description,
        'categories': jsonEncode(e.categories),
        'date': e.date.toIso8601String(),
        'image_path': e.imagePath,
        'type': e.type,
        'distribution':
            e.distribution != null ? jsonEncode(e.distribution) : null,
      };

  static ExpenseModel _mapToExpense(Map<String, dynamic> m) => ExpenseModel(
        id: m['id'] as String,
        groupId: m['group_id'] as String,
        amount: (m['amount'] as num).toDouble(),
        description: m['description'] as String,
        categories:
            List<String>.from(jsonDecode(m['categories'] as String)),
        date: DateTime.parse(m['date'] as String),
        imagePath: m['image_path'] as String?,
        type: m['type'] as String? ?? 'debit',
        distribution: m['distribution'] != null
            ? Map<String, double>.from(
                (jsonDecode(m['distribution'] as String) as Map)
                    .map((k, v) => MapEntry(k as String, (v as num).toDouble())))
            : null,
      );

  static Map<String, dynamic> _recurringToMap(RecurringExpenseModel r) => {
        'id': r.id,
        'name': r.name,
        'amount': r.amount,
        'frequency': r.frequency,
        'start_date': r.startDate.toIso8601String(),
        'end_date': r.endDate?.toIso8601String(),
        'group_id': r.groupId,
        'categories': jsonEncode(r.categories),
        'description': r.description,
        'is_active': r.isActive ? 1 : 0,
        'last_generated_date': r.lastGeneratedDate?.toIso8601String(),
        'distribution':
            r.distribution != null ? jsonEncode(r.distribution) : null,
      };

  static RecurringExpenseModel _mapToRecurring(Map<String, dynamic> m) =>
      RecurringExpenseModel(
        id: m['id'] as String,
        name: m['name'] as String,
        amount: (m['amount'] as num).toDouble(),
        frequency: m['frequency'] as String,
        startDate: DateTime.parse(m['start_date'] as String),
        endDate: m['end_date'] != null
            ? DateTime.parse(m['end_date'] as String)
            : null,
        groupId: m['group_id'] as String,
        categories:
            List<String>.from(jsonDecode(m['categories'] as String)),
        description: m['description'] as String? ?? '',
        isActive: (m['is_active'] as int) == 1,
        lastGeneratedDate: m['last_generated_date'] != null
            ? DateTime.parse(m['last_generated_date'] as String)
            : null,
        distribution: m['distribution'] != null
            ? Map<String, double>.from(
                (jsonDecode(m['distribution'] as String) as Map)
                    .map((k, v) => MapEntry(k as String, (v as num).toDouble())))
            : null,
      );

  static Map<String, dynamic> _emiToMap(EmiModel e) => {
        'id': e.id,
        'product_name': e.productName,
        'amount': e.amount,
        'tenure': e.tenure,
        'completed': e.completed,
        'start_date': e.startDate.toIso8601String(),
        'group_id': e.groupId,
        'categories': jsonEncode(e.categories),
        'description': e.description,
        'last_generated_date': e.lastGeneratedDate?.toIso8601String(),
        'distribution':
            e.distribution != null ? jsonEncode(e.distribution) : null,
      };

  static EmiModel _mapToEmi(Map<String, dynamic> m) => EmiModel(
        id: m['id'] as String,
        productName: m['product_name'] as String,
        amount: (m['amount'] as num).toDouble(),
        tenure: m['tenure'] as int,
        completed: m['completed'] as int? ?? 0,
        startDate: DateTime.parse(m['start_date'] as String),
        groupId: m['group_id'] as String,
        categories:
            List<String>.from(jsonDecode(m['categories'] as String)),
        description: m['description'] as String? ?? '',
        lastGeneratedDate: m['last_generated_date'] != null
            ? DateTime.parse(m['last_generated_date'] as String)
            : null,
        distribution: m['distribution'] != null
            ? Map<String, double>.from(
                (jsonDecode(m['distribution'] as String) as Map)
                    .map((k, v) => MapEntry(k as String, (v as num).toDouble())))
            : null,
      );

  static Map<String, dynamic> _personToMap(PersonModel p) => {
        'id': p.id,
        'name': p.name,
        'photo_path': p.photoPath,
        'phone': p.phone,
        'address': p.address,
        'grp': p.group,
        'notes': p.notes,
        'created_at': p.createdAt.toIso8601String(),
      };

  static PersonModel _mapToPerson(Map<String, dynamic> m) => PersonModel(
        id: m['id'] as String,
        name: m['name'] as String,
        photoPath: m['photo_path'] as String?,
        phone: m['phone'] as String?,
        address: m['address'] as String?,
        group: m['grp'] as String?,
        notes: m['notes'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  static Map<String, dynamic> _txToMap(LedgerTransactionModel t) => {
        'id': t.id,
        'person_id': t.personId,
        'type': t.type.name,
        'amount': t.amount,
        'description': t.description,
        'category': t.category,
        'attachment_path': t.attachmentPath,
        'notes': t.notes,
        'transaction_date': t.transactionDate.toIso8601String(),
        'created_at': t.createdAt.toIso8601String(),
      };

  static LedgerTransactionModel _mapToTx(Map<String, dynamic> m) =>
      LedgerTransactionModel(
        id: m['id'] as String,
        personId: m['person_id'] as String,
        type: UdhaarTransactionType.values.firstWhere(
          (e) => e.name == m['type'],
          orElse: () => UdhaarTransactionType.collection,
        ),
        amount: (m['amount'] as num).toDouble(),
        description: m['description'] as String? ?? '',
        category: m['category'] as String?,
        attachmentPath: m['attachment_path'] as String?,
        notes: m['notes'] as String?,
        transactionDate:
            DateTime.parse(m['transaction_date'] as String),
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
