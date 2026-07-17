import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/custom_category.dart';
import '../models/expense.dart';
import '../models/ai_log.dart';
import '../models/transaction_query.dart';
import '../models/assistant_message.dart';
import 'transaction_duplicate_detector.dart';

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
      version: 14,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    await _createExpensesTable(db);
    await _createAiLogsTable(db);
    await _createParsedSmsTable(db);
    await _createCustomCategoriesTable(db);
    await _createMerchantCategoryMapTable(db);
    await _createAppMetadataTable(db);
    await _createExpenseIndexes(db);
    await _createAssistantMessagesTable(db);
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await _createAiLogsTable(db);
    if (oldVersion < 3) {
      await _createParsedSmsTable(db);
      await db.execute('''
        INSERT OR IGNORE INTO parsed_sms (body, sender, date, parsed_at)
        SELECT originalSms, '', 0, date FROM expenses
      ''');
    }
    if (oldVersion < 4) {
      await db.execute(
        "ALTER TABLE expenses ADD COLUMN type TEXT NOT NULL DEFAULT 'expense'",
      );
    }
    if (oldVersion < 5) {
      await db.execute(
        "ALTER TABLE expenses ADD COLUMN tags TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE expenses ADD COLUMN split_share REAL DEFAULT NULL",
      );
      await db.execute(
        "ALTER TABLE expenses ADD COLUMN is_recurring INTEGER NOT NULL DEFAULT 0",
      );
      await db.execute(
        "ALTER TABLE expenses ADD COLUMN normalized_merchant TEXT DEFAULT NULL",
      );
    }
    if (oldVersion < 6) {
      await _createCustomCategoriesTable(db);
    }
    if (oldVersion < 7) {
      await _createMerchantCategoryMapTable(db);
      await _createAppMetadataTable(db);
    }
    if (oldVersion < 8) {
      // Columns may already exist if the DB was created at v3+ with the updated
      // _createParsedSmsTable schema. Ignore "duplicate column" errors.
      try {
        await db.execute(
          "ALTER TABLE parsed_sms ADD COLUMN sender TEXT DEFAULT ''",
        );
      } catch (_) {}
      try {
        await db.execute(
          "ALTER TABLE parsed_sms ADD COLUMN date INTEGER DEFAULT 0",
        );
      } catch (_) {}
    }
    if (oldVersion < 10) {
      try {
        await db.execute(
          "ALTER TABLE parsed_sms ADD COLUMN skip_reason TEXT NOT NULL DEFAULT ''",
        );
      } catch (_) {}
    }
    if (oldVersion < 12) await _createExpenseIndexes(db);
    if (oldVersion < 13) await _createAssistantMessagesTable(db);
    if (oldVersion < 14) {
      await db.execute(
        "ALTER TABLE assistant_messages ADD COLUMN filter_details TEXT NOT NULL DEFAULT ''",
      );
    }
  }

  // ─── Table definitions ───────────────────────────────────────────────────

  Future _createExpensesTable(Database db) async {
    await db.execute('''
CREATE TABLE expenses (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  amount              REAL    NOT NULL,
  currency            TEXT    NOT NULL,
  merchant            TEXT    NOT NULL,
  category            TEXT    NOT NULL,
  date                TEXT    NOT NULL,
  originalSms         TEXT    NOT NULL,
  type                TEXT    NOT NULL DEFAULT 'expense',
  tags                TEXT    NOT NULL DEFAULT '',
  split_share         REAL    DEFAULT NULL,
  is_recurring        INTEGER NOT NULL DEFAULT 0,
  normalized_merchant TEXT    DEFAULT NULL
)
''');
  }

  Future<void> _createExpenseIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(date DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_expenses_category_date ON expenses(category, date DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_expenses_type_date ON expenses(type, date DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_expenses_currency_date ON expenses(currency, date DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_expenses_merchant_date ON expenses(normalized_merchant, merchant, date DESC)',
    );
  }

  Future<void> _createAssistantMessagesTable(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS assistant_messages (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  is_user   INTEGER NOT NULL,
  text      TEXT    NOT NULL,
  sources   INTEGER NOT NULL DEFAULT 0,
  verified  INTEGER NOT NULL DEFAULT 0,
  filter_details TEXT NOT NULL DEFAULT '',
  timestamp TEXT    NOT NULL
)
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_assistant_messages_time ON assistant_messages(timestamp)',
    );
  }

  Future<List<AssistantMessage>> getAssistantMessages({int limit = 100}) async {
    final db = await instance.database;
    final rows = await db.query(
      'assistant_messages',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return rows.reversed.map(AssistantMessage.fromMap).toList();
  }

  Future<AssistantMessage> insertAssistantMessage(
    AssistantMessage message,
  ) async {
    final db = await instance.database;
    final id = await db.insert('assistant_messages', message.toMap());
    return AssistantMessage(
      id: id,
      user: message.user,
      text: message.text,
      sources: message.sources,
      verified: message.verified,
      filterDetails: message.filterDetails,
      timestamp: message.timestamp,
    );
  }

  Future<void> clearAssistantMessages() async {
    final db = await instance.database;
    await db.delete('assistant_messages');
  }

  Future _createAiLogsTable(Database db) async {
    await db.execute('''
CREATE TABLE ai_logs (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  requestPrompt TEXT    NOT NULL,
  responseBody  TEXT    NOT NULL,
  timestamp     TEXT    NOT NULL,
  status        TEXT    NOT NULL
)
''');
  }

  Future _createParsedSmsTable(Database db) async {
    await db.execute('''
CREATE TABLE parsed_sms (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  body        TEXT    NOT NULL,
  sender      TEXT    NOT NULL DEFAULT '',
  date        INTEGER NOT NULL DEFAULT 0,
  parsed_at   TEXT    NOT NULL,
  skip_reason TEXT    NOT NULL DEFAULT '',
  UNIQUE(body, sender, date)
)
''');
  }

  Future _createCustomCategoriesTable(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS custom_categories (
  id    INTEGER PRIMARY KEY AUTOINCREMENT,
  name  TEXT    NOT NULL UNIQUE,
  icon  TEXT    NOT NULL DEFAULT 'e148',
  color TEXT    NOT NULL DEFAULT 'FF607D8B'
)
''');
  }

  Future _createMerchantCategoryMapTable(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS merchant_category_map (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  merchant_key  TEXT    NOT NULL UNIQUE,
  category      TEXT    NOT NULL,
  updated_at    TEXT    NOT NULL
)
''');
  }

  Future _createAppMetadataTable(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS app_metadata (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
)
''');
    await db.execute(
      "INSERT OR IGNORE INTO app_metadata (key, value) VALUES ('last_sync_at', '')",
    );
  }

  // ─── Expense CRUD ────────────────────────────────────────────────────────

  Future<int> insertExpense(Expense expense) async {
    final db = await instance.database;
    return await db.insert('expenses', expense.toMap());
  }

  Future<void> insertExpenses(List<Expense> expenses) async {
    if (expenses.isEmpty) return;
    final db = await instance.database;
    final batch = db.batch();
    for (final e in expenses) {
      batch.insert('expenses', e.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<List<Expense>> insertExpensesReturning(List<Expense> expenses) async {
    if (expenses.isEmpty) return const [];
    final db = await instance.database;
    const detector = TransactionDuplicateDetector();
    return db.transaction((txn) async {
      final inserted = <Expense>[];
      for (final expense in expenses) {
        final from = expense.date
            .subtract(TransactionDuplicateDetector.candidateWindow)
            .toIso8601String();
        final to = expense.date
            .add(TransactionDuplicateDetector.candidateWindow)
            .toIso8601String();
        final rows = await txn.query(
          'expenses',
          where:
              'amount = ? AND currency = ? AND type = ? AND date BETWEEN ? AND ?',
          whereArgs: [expense.amount, expense.currency, expense.type, from, to],
        );
        final duplicate = rows
            .map(Expense.fromMap)
            .any((existing) => detector.isDuplicate(expense, existing));
        if (duplicate) continue;
        final id = await txn.insert('expenses', expense.toMap());
        inserted.add(expense.copyWith(id: id));
      }
      return inserted;
    });
  }

  Future<int> updateExpense(Expense expense) async {
    final db = await instance.database;
    return await db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<int> deleteExpense(int id) async {
    final db = await instance.database;
    return await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Expense>> getAllExpenses() async {
    final db = await instance.database;
    final result = await db.query('expenses', orderBy: 'date DESC');
    return result.map((json) => Expense.fromMap(json)).toList();
  }

  Future<Expense?> getExpenseById(int id) async {
    final db = await instance.database;
    final rows = await db.query(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Expense.fromMap(rows.single);
  }

  /// Executes the bounded query language used by the money assistant.
  /// Values are always bound parameters; model-generated SQL is never accepted.
  Future<List<Expense>> queryTransactions(TransactionQuery query) async {
    final db = await instance.database;
    final filter = _transactionFilter(query);
    final rows = await db.query(
      'expenses',
      where: filter.where,
      whereArgs: filter.arguments,
      orderBy: 'date DESC',
      limit: query.limit,
    );
    return rows.map(Expense.fromMap).toList();
  }

  Future<Map<String, dynamic>> summarizeTransactions(
    TransactionQuery query,
  ) async {
    final db = await instance.database;
    final filter = _transactionFilter(query);
    final rows = await db.rawQuery('''
SELECT currency, type, COUNT(*) AS record_count, COALESCE(SUM(amount), 0) AS total
FROM expenses
${filter.where == null ? '' : 'WHERE ${filter.where}'}
GROUP BY currency, type
''', filter.arguments);
    var count = 0;
    final totals = <String, Map<String, double>>{};
    for (final row in rows) {
      count += (row['record_count'] as num).toInt();
      final currency = row['currency'].toString();
      final type = row['type'].toString();
      totals.putIfAbsent(currency, () => {'income': 0, 'expense': 0})[type] =
          (row['total'] as num).toDouble();
    }
    return {
      'applied_filter': query.toJson(),
      'matched_count': count,
      'totals_by_currency': totals,
    };
  }

  ({String? where, List<Object?> arguments}) _transactionFilter(
    TransactionQuery query,
  ) {
    final clauses = <String>[];
    final arguments = <Object?>[];

    void add(String clause, Object? value) {
      clauses.add(clause);
      arguments.add(value);
    }

    if (query.from != null) add('date >= ?', query.from!.toIso8601String());
    if (query.to != null) add('date <= ?', query.to!.toIso8601String());
    if (query.merchant != null) {
      clauses.add(
        '(LOWER(merchant) LIKE ? OR LOWER(COALESCE(normalized_merchant, merchant)) LIKE ?)',
      );
      final value = '%${query.merchant!.toLowerCase()}%';
      arguments.addAll([value, value]);
    }
    if (query.category != null) {
      add('LOWER(category) = ?', query.category!.toLowerCase());
    }
    if (query.direction != null) add('type = ?', query.direction);
    if (query.currency != null) add('UPPER(currency) = ?', query.currency);
    if (query.minimumAmount != null) add('amount >= ?', query.minimumAmount);
    if (query.maximumAmount != null) add('amount <= ?', query.maximumAmount);
    if (query.text != null) {
      clauses.add(
        '(LOWER(merchant) LIKE ? OR LOWER(COALESCE(normalized_merchant, merchant)) LIKE ? '
        'OR LOWER(category) LIKE ? OR LOWER(tags) LIKE ?)',
      );
      final value = '%${query.text!.toLowerCase()}%';
      arguments.addAll([value, value, value, value]);
    }
    return (
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      arguments: arguments,
    );
  }

  Future<bool> smsExists(String originalSms) async {
    final db = await instance.database;
    final result = await db.query(
      'expenses',
      columns: ['id'],
      where: 'originalSms = ?',
      whereArgs: [originalSms],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  // ─── Parsed SMS ──────────────────────────────────────────────────────────

  Future<bool> isSmsParsed(String body, String sender, int date) async {
    final db = await instance.database;
    final result = await db.query(
      'parsed_sms',
      columns: ['id'],
      where: 'body = ? AND sender = ? AND date = ?',
      whereArgs: [body, sender, date],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<Set<String>> getParsedSmsKeys(int sinceTimestamp) async {
    final db = await instance.database;
    final rows = await db.query(
      'parsed_sms',
      columns: ['body', 'sender', 'date'],
      where: 'date >= ?',
      whereArgs: [sinceTimestamp],
    );
    return rows.map((r) => '${r['sender']}|${r['body']}|${r['date']}').toSet();
  }

  Future<void> markSmsBatchParsed(
    List<Map<String, dynamic>> smsList, {
    Map<String, String> skipReasons = const {},
  }) async {
    if (smsList.isEmpty) return;
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final sms in smsList) {
      final body = sms['body'] as String;
      batch.insert('parsed_sms', {
        'body': body,
        'sender': sms['address'],
        'date': sms['timestamp'],
        'parsed_at': now,
        'skip_reason': skipReasons[body] ?? '',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getParsedSmsAudit() async {
    final db = await instance.database;
    final rows = await db.rawQuery('''
      SELECT
        p.id,
        p.body,
        p.parsed_at,
        p.skip_reason,
        CASE WHEN e.id IS NOT NULL THEN 1 ELSE 0 END AS has_expense
      FROM parsed_sms p
      LEFT JOIN expenses e ON e.originalSms = p.body
      GROUP BY p.id
      ORDER BY p.parsed_at DESC
    ''');
    return rows;
  }

  // ─── Custom Categories ────────────────────────────────────────────────────

  Future<List<CustomCategory>> getAllCustomCategories() async {
    final db = await instance.database;
    final result = await db.query('custom_categories', orderBy: 'name ASC');
    return result.map(CustomCategory.fromMap).toList();
  }

  Future<void> insertOrUpdateCustomCategory(CustomCategory cat) async {
    final db = await instance.database;
    await db.insert(
      'custom_categories',
      cat.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteCustomCategory(int id) async {
    final db = await instance.database;
    await db.delete('custom_categories', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Merchant category learning ───────────────────────────────────────────

  Future<Map<String, String>> getMerchantCategoryMap() async {
    final db = await instance.database;
    final rows = await db.query('merchant_category_map');
    return {
      for (final r in rows)
        r['merchant_key'] as String: r['category'] as String,
    };
  }

  Future<void> upsertMerchantCategory(
    String merchantKey,
    String category,
  ) async {
    final db = await instance.database;
    await db.insert('merchant_category_map', {
      'merchant_key': merchantKey.toLowerCase().trim(),
      'category': category,
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ─── App metadata ─────────────────────────────────────────────────────────

  Future<String?> getAppMetadata(String key) async {
    final db = await instance.database;
    final result = await db.query(
      'app_metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (result.isEmpty) return null;
    final val = result.first['value'] as String?;
    return (val == null || val.isEmpty) ? null : val;
  }

  Future<void> setAppMetadata(String key, String value) async {
    final db = await instance.database;
    await db.insert('app_metadata', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ─── AI Log methods ──────────────────────────────────────────────────────

  Future<int> insertAiLog(AiLog log) async {
    final db = await instance.database;
    return await db.insert('ai_logs', log.toMap());
  }

  Future<List<AiLog>> getAllAiLogs() async {
    final db = await instance.database;
    final result = await db.query('ai_logs', orderBy: 'timestamp DESC');
    return result.map((json) => AiLog.fromMap(json)).toList();
  }

  Future<void> clearAiLogs() async {
    final db = await instance.database;
    await db.delete('ai_logs');
  }

  // ─── Parsed SMS retry ────────────────────────────────────────────────────

  Future<void> unmarkSmsParsed(List<String> bodies) async {
    if (bodies.isEmpty) return;
    final db = await instance.database;
    final placeholders = List.filled(bodies.length, '?').join(', ');
    await db.rawDelete(
      'DELETE FROM parsed_sms WHERE body IN ($placeholders)',
      bodies,
    );
  }

  Future close() async {
    final db = _database;
    if (db != null) await db.close();
    _database = null;
  }
}
