import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbDir = await getDatabasesPath();
    final dbPath = p.join(dbDir, 'siteshinn.db');
    return openDatabase(
      dbPath,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE accounts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        currency_code TEXT NOT NULL DEFAULT 'MMK',
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE members (
        id TEXT PRIMARY KEY,
        account_id TEXT NOT NULL,
        name TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE cycles (
        id TEXT PRIMARY KEY,
        account_id TEXT NOT NULL,
        title TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT,
        is_settled INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        account_id TEXT NOT NULL,
        cycle_id TEXT NOT NULL,
        paid_by_member_id TEXT NOT NULL,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        expense_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
        FOREIGN KEY (cycle_id) REFERENCES cycles(id) ON DELETE CASCADE,
        FOREIGN KEY (paid_by_member_id) REFERENCES members(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE expense_splits (
        id TEXT PRIMARY KEY,
        expense_id TEXT NOT NULL,
        member_id TEXT NOT NULL,
        share_amount REAL NOT NULL,
        FOREIGN KEY (expense_id) REFERENCES expenses(id) ON DELETE CASCADE,
        FOREIGN KEY (member_id) REFERENCES members(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE settlement_transfers (
        id TEXT PRIMARY KEY,
        cycle_id TEXT NOT NULL,
        from_member_id TEXT NOT NULL,
        to_member_id TEXT NOT NULL,
        amount REAL NOT NULL,
        FOREIGN KEY (cycle_id) REFERENCES cycles(id) ON DELETE CASCADE,
        FOREIGN KEY (from_member_id) REFERENCES members(id),
        FOREIGN KEY (to_member_id) REFERENCES members(id)
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_members_account ON members(account_id)',
    );
    await db.execute(
      'CREATE INDEX idx_cycles_account ON cycles(account_id, is_settled)',
    );
    await db.execute(
      'CREATE INDEX idx_expenses_cycle ON expenses(cycle_id, expense_date DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_splits_expense ON expense_splits(expense_id)',
    );
  }
}
