import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/expense.dart';
import '../models/ai_log.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('expenses.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    await _createExpensesTable(db);
    await _createAiLogsTable(db);
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createAiLogsTable(db);
    }
  }

  Future _createExpensesTable(Database db) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const doubleType = 'REAL NOT NULL';

    await db.execute('''
CREATE TABLE expenses (
  id $idType,
  amount $doubleType,
  currency $textType,
  merchant $textType,
  category $textType,
  date $textType,
  originalSms $textType
)
''');
  }

  Future _createAiLogsTable(Database db) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';

    await db.execute('''
CREATE TABLE ai_logs (
  id $idType,
  requestPrompt $textType,
  responseBody $textType,
  timestamp $textType,
  status $textType
)
''');
  }

  // Expense Methods
  Future<int> insertExpense(Expense expense) async {
    final db = await instance.database;
    return await db.insert('expenses', expense.toMap());
  }

  Future<List<Expense>> getAllExpenses() async {
    final db = await instance.database;
    const orderBy = 'date DESC';
    final result = await db.query('expenses', orderBy: orderBy);

    return result.map((json) => Expense.fromMap(json)).toList();
  }

  Future<bool> smsExists(String originalSms) async {
    final db = await instance.database;
    final result = await db.query(
      'expenses',
      where: 'originalSms = ?',
      whereArgs: [originalSms],
    );
    return result.isNotEmpty;
  }

  // AI Log Methods
  Future<int> insertAiLog(AiLog log) async {
    final db = await instance.database;
    return await db.insert('ai_logs', log.toMap());
  }

  Future<List<AiLog>> getAllAiLogs() async {
    final db = await instance.database;
    const orderBy = 'timestamp DESC';
    final result = await db.query('ai_logs', orderBy: orderBy);

    return result.map((json) => AiLog.fromMap(json)).toList();
  }

  Future<void> clearAiLogs() async {
    final db = await instance.database;
    await db.delete('ai_logs');
  }

  Future close() async {
    final db = _database;
    if (db != null) {
      await db.close();
    }
  }
}
