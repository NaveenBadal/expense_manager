import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/custom_category.dart';
import '../models/expense.dart';
import '../models/ai_log.dart';
import '../models/transaction_query.dart';
import '../models/assistant_message.dart';
import '../models/budget.dart';
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
      version: 18,
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
    await _createBudgetsTable(db);
    await _createAgentMemoryTable(db);
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
    if (oldVersion < 15) {
      await db.execute(
        "ALTER TABLE assistant_messages ADD COLUMN artifact_json TEXT NOT NULL DEFAULT ''",
      );
    }
    if (oldVersion < 16) await _createBudgetsTable(db);
    if (oldVersion < 17) {
      for (final statement in const [
        "ALTER TABLE expenses ADD COLUMN account TEXT",
        "ALTER TABLE expenses ADD COLUMN counterparty_account TEXT",
        "ALTER TABLE expenses ADD COLUMN status TEXT NOT NULL DEFAULT 'settled'",
        "ALTER TABLE expenses ADD COLUMN source TEXT NOT NULL DEFAULT 'manual'",
        "ALTER TABLE expenses ADD COLUMN confidence REAL NOT NULL DEFAULT 1",
        "ALTER TABLE expenses ADD COLUMN transfer_group TEXT",
        "ALTER TABLE expenses ADD COLUMN notes TEXT NOT NULL DEFAULT ''",
      ]) {
        await db.execute(statement);
      }
    }
    if (oldVersion < 18) await _createAgentMemoryTable(db);
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
  ,account            TEXT    DEFAULT NULL
  ,counterparty_account TEXT  DEFAULT NULL
  ,status             TEXT    NOT NULL DEFAULT 'settled'
  ,source             TEXT    NOT NULL DEFAULT 'manual'
  ,confidence         REAL    NOT NULL DEFAULT 1
  ,transfer_group     TEXT    DEFAULT NULL
  ,notes              TEXT    NOT NULL DEFAULT ''
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
  artifact_json TEXT NOT NULL DEFAULT '',
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
      artifactJson: message.artifactJson,
      timestamp: message.timestamp,
    );
  }

  Future<void> _createBudgetsTable(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS budgets (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  name            TEXT    NOT NULL,
  amount          REAL    NOT NULL CHECK(amount > 0),
  currency        TEXT    NOT NULL,
  category        TEXT,
  warning_percent INTEGER NOT NULL DEFAULT 75,
  created_at      TEXT    NOT NULL
)
''');
  }

  Future<void> _createAgentMemoryTable(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS agent_memory (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  memory_key TEXT    NOT NULL UNIQUE,
  value      TEXT    NOT NULL,
  created_at TEXT    NOT NULL,
  updated_at TEXT    NOT NULL
)
''');
  }

  Future<List<Map<String, dynamic>>> getAgentMemories() async {
    final db = await instance.database;
    return db.query('agent_memory', orderBy: 'updated_at DESC', limit: 50);
  }

  Future<void> rememberAgentPreference(String key, String value) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    await db.insert('agent_memory', {
      'memory_key': key.trim().toLowerCase(),
      'value': value.trim(),
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> forgetAgentPreference(String key) async {
    final db = await instance.database;
    return db.delete(
      'agent_memory',
      where: 'memory_key = ?',
      whereArgs: [key.trim().toLowerCase()],
    );
  }

  Future<List<Budget>> getBudgets() async {
    final db = await instance.database;
    final rows = await db.query('budgets', orderBy: 'created_at DESC');
    return rows.map(Budget.fromMap).toList();
  }

  Future<int> insertBudget(Budget budget) async {
    final db = await instance.database;
    return db.insert('budgets', budget.toMap());
  }

  Future<Budget?> getBudgetById(int id) async {
    final db = await instance.database;
    final rows = await db.query(
      'budgets',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Budget.fromMap(rows.single);
  }

  Future<int> deleteBudget(int id) async {
    final db = await instance.database;
    return db.delete('budgets', where: 'id = ?', whereArgs: [id]);
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

  Future<List<Expense>> bulkUpdateExpenses(
    TransactionQuery query,
    Map<String, dynamic> changes,
  ) async {
    final db = await instance.database;
    final filter = _transactionFilter(query);
    if (filter.where == null) {
      throw ArgumentError('A bulk update requires at least one filter.');
    }
    return db.transaction((txn) async {
      final rows = await txn.query(
        'expenses',
        where: filter.where,
        whereArgs: filter.arguments,
        orderBy: 'date DESC',
        limit: 200,
      );
      final originals = rows.map(Expense.fromMap).toList();
      if (originals.isEmpty) return const [];
      final allowed = <String, Object?>{
        if (changes['category'] != null) 'category': changes['category'],
        if (changes['merchant'] != null) 'merchant': changes['merchant'],
        if (changes['tags'] != null) 'tags': changes['tags'],
        if (changes['status'] != null) 'status': changes['status'],
        if (changes['account'] != null) 'account': changes['account'],
      };
      if (allowed.isEmpty) {
        throw ArgumentError('No supported changes supplied.');
      }
      await txn.update(
        'expenses',
        allowed,
        where: filter.where,
        whereArgs: filter.arguments,
      );
      return originals;
    });
  }

  Future<void> restoreExpenses(List<Expense> originals) async {
    if (originals.isEmpty) return;
    final db = await instance.database;
    await db.transaction((txn) async {
      for (final expense in originals) {
        await txn.update(
          'expenses',
          expense.toMap(),
          where: 'id = ?',
          whereArgs: [expense.id],
        );
      }
    });
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

  Future<Map<String, dynamic>> spendingBreakdown(
    TransactionQuery query, {
    required String groupBy,
  }) async {
    final db = await instance.database;
    final filter = _transactionFilter(query);
    final expression = switch (groupBy) {
      'merchant' => 'COALESCE(normalized_merchant, merchant)',
      'day' => 'SUBSTR(date, 1, 10)',
      'direction' => 'type',
      _ => 'category',
    };
    final rows = await db.rawQuery('''
SELECT $expression AS label, currency, type, COUNT(*) AS record_count,
       COALESCE(SUM(amount), 0) AS total
FROM expenses
${filter.where == null ? '' : 'WHERE ${filter.where}'}
GROUP BY $expression, currency, type
ORDER BY total DESC
''', filter.arguments);
    final groups = rows
        .map(
          (row) => {
            'label': row['label']?.toString() ?? 'Unknown',
            'currency': row['currency'].toString(),
            'direction': row['type'].toString(),
            'count': (row['record_count'] as num).toInt(),
            'total': (row['total'] as num).toDouble(),
          },
        )
        .toList();
    return {
      'applied_filter': query.toJson(),
      'group_by': groupBy,
      'matched_count': groups.fold<int>(
        0,
        (sum, row) => sum + (row['count'] as int),
      ),
      'groups': groups,
    };
  }

  Future<Map<String, dynamic>> comparePeriods(
    TransactionQuery first,
    TransactionQuery second,
  ) async {
    final firstResult = await summarizeTransactions(first);
    final secondResult = await summarizeTransactions(second);
    final currencies = <String>{
      ...((firstResult['totals_by_currency'] as Map).keys.map(
        (value) => value.toString(),
      )),
      ...((secondResult['totals_by_currency'] as Map).keys.map(
        (value) => value.toString(),
      )),
    };
    final comparisons = <Map<String, dynamic>>[];
    for (final currency in currencies) {
      final firstTotals =
          ((firstResult['totals_by_currency'] as Map)[currency] as Map?)
              ?.cast<String, dynamic>() ??
          const {};
      final secondTotals =
          ((secondResult['totals_by_currency'] as Map)[currency] as Map?)
              ?.cast<String, dynamic>() ??
          const {};
      for (final direction in const ['expense', 'income']) {
        final firstValue = (firstTotals[direction] as num?)?.toDouble() ?? 0;
        final secondValue = (secondTotals[direction] as num?)?.toDouble() ?? 0;
        final change = secondValue - firstValue;
        comparisons.add({
          'currency': currency,
          'direction': direction,
          'first': firstValue,
          'second': secondValue,
          'change': change,
          'change_percent': firstValue == 0
              ? null
              : (change / firstValue) * 100,
        });
      }
    }
    return {
      'first': firstResult,
      'second': secondResult,
      'comparisons': comparisons,
      'matched_count':
          (firstResult['matched_count'] as int) +
          (secondResult['matched_count'] as int),
    };
  }

  Future<Map<String, dynamic>> detectRecurringTransactions({
    int lookbackDays = 180,
  }) async {
    final from = DateTime.now().subtract(Duration(days: lookbackDays));
    final records = await queryTransactions(
      TransactionQuery(from: from, direction: 'expense', limit: 200),
    );
    final groups = <String, List<Expense>>{};
    for (final record in records) {
      final key = record.displayMerchant.trim().toLowerCase();
      if (key.isEmpty || key == 'unknown') continue;
      groups.putIfAbsent(key, () => []).add(record);
    }
    final recurring = <Map<String, dynamic>>[];
    for (final entry in groups.entries) {
      final values = entry.value..sort((a, b) => a.date.compareTo(b.date));
      if (values.length < 2) continue;
      final intervals = <int>[];
      for (var index = 1; index < values.length; index++) {
        intervals.add(
          values[index].date.difference(values[index - 1].date).inDays,
        );
      }
      final averageDays = intervals.reduce((a, b) => a + b) / intervals.length;
      if (averageDays < 5 || averageDays > 45) continue;
      final averageAmount =
          values.fold<double>(0, (sum, item) => sum + item.amount) /
          values.length;
      final variance =
          values.fold<double>(
            0,
            (sum, item) => sum + (item.amount - averageAmount).abs(),
          ) /
          values.length;
      if (variance > averageAmount * 0.35) continue;
      recurring.add({
        'merchant': values.first.displayMerchant,
        'currency': values.first.currency,
        'average_amount': averageAmount,
        'frequency_days': averageDays.round(),
        'occurrences': values.length,
        'last_date': values.last.date.toIso8601String(),
        'next_expected': values.last.date
            .add(Duration(days: averageDays.round()))
            .toIso8601String(),
      });
    }
    recurring.sort(
      (a, b) => (b['average_amount'] as double).compareTo(
        a['average_amount'] as double,
      ),
    );
    return {
      'lookback_days': lookbackDays,
      'matched_count': records.length,
      'recurring': recurring,
    };
  }

  Future<Map<String, dynamic>> detectAnomalies({int lookbackDays = 90}) async {
    final records = await queryTransactions(
      TransactionQuery(
        from: DateTime.now().subtract(Duration(days: lookbackDays)),
        direction: 'expense',
        limit: 200,
      ),
    );
    final byCurrency = <String, List<Expense>>{};
    for (final record in records) {
      byCurrency.putIfAbsent(record.currency, () => []).add(record);
    }
    final anomalies = <Map<String, dynamic>>[];
    for (final entry in byCurrency.entries) {
      if (entry.value.length < 5) continue;
      final amounts = entry.value.map((value) => value.amount).toList()..sort();
      final median = amounts[amounts.length ~/ 2];
      final threshold = median * 3;
      for (final record in entry.value.where(
        (value) => value.amount > threshold,
      )) {
        anomalies.add({
          'id': record.id,
          'merchant': record.displayMerchant,
          'amount': record.amount,
          'currency': record.currency,
          'date': record.date.toIso8601String(),
          'reason': 'More than 3× the median ${record.currency} expense',
        });
      }
    }
    anomalies.sort(
      (a, b) => (b['amount'] as double).compareTo(a['amount'] as double),
    );
    return {
      'lookback_days': lookbackDays,
      'matched_count': records.length,
      'anomalies': anomalies.take(20).toList(),
    };
  }

  Future<Map<String, dynamic>> findDuplicateTransactions({
    int lookbackDays = 90,
  }) async {
    final records = await queryTransactions(
      TransactionQuery(
        from: DateTime.now().subtract(Duration(days: lookbackDays)),
        limit: 200,
      ),
    );
    const detector = TransactionDuplicateDetector();
    final duplicates = <Map<String, dynamic>>[];
    final used = <int>{};
    for (var first = 0; first < records.length; first++) {
      for (var second = first + 1; second < records.length; second++) {
        if (used.contains(second)) continue;
        if (!detector.isDuplicate(records[first], records[second])) continue;
        used.add(second);
        duplicates.add({
          'first': _assistantRecord(records[first]),
          'possible_duplicate': _assistantRecord(records[second]),
        });
      }
    }
    return {
      'lookback_days': lookbackDays,
      'matched_count': records.length,
      'duplicate_pairs': duplicates,
    };
  }

  Map<String, dynamic> _assistantRecord(Expense record) => {
    'id': record.id,
    'merchant': record.displayMerchant,
    'amount': record.amount,
    'currency': record.currency,
    'date': record.date.toIso8601String(),
    'category': record.category,
  };

  Future<Map<String, dynamic>> cashflowForecast({int horizonDays = 30}) async {
    final now = DateTime.now();
    final lookback = horizonDays * 3;
    final summary = await summarizeTransactions(
      TransactionQuery(from: now.subtract(Duration(days: lookback))),
    );
    final forecast = <Map<String, dynamic>>[];
    for (final entry in (summary['totals_by_currency'] as Map).entries) {
      final totals = (entry.value as Map).cast<String, dynamic>();
      final scale = horizonDays / lookback;
      final income = ((totals['income'] as num?)?.toDouble() ?? 0) * scale;
      final expense = ((totals['expense'] as num?)?.toDouble() ?? 0) * scale;
      forecast.add({
        'currency': entry.key.toString(),
        'projected_income': income,
        'projected_expense': expense,
        'projected_net': income - expense,
        'basis_days': lookback,
        'horizon_days': horizonDays,
      });
    }
    return {
      'matched_count': summary['matched_count'],
      'forecast': forecast,
      'method': 'Trailing $lookback-day daily average; not financial advice.',
    };
  }

  Future<Map<String, dynamic>> budgetStatus() async {
    final budgets = await getBudgets();
    final now = DateTime.now();
    final from = DateTime(now.year, now.month);
    final statuses = <Map<String, dynamic>>[];
    for (final budget in budgets) {
      final summary = await summarizeTransactions(
        TransactionQuery(
          from: from,
          to: now,
          category: budget.category,
          direction: 'expense',
          currency: budget.currency,
        ),
      );
      final values =
          ((summary['totals_by_currency'] as Map)[budget.currency] as Map?)
              ?.cast<String, dynamic>() ??
          const {};
      final spent = (values['expense'] as num?)?.toDouble() ?? 0;
      statuses.add({
        'id': budget.id,
        'name': budget.name,
        'category': budget.category,
        'currency': budget.currency,
        'limit': budget.amount,
        'spent': spent,
        'remaining': budget.amount - spent,
        'percent_used': budget.amount == 0 ? 0 : (spent / budget.amount) * 100,
        'warning_percent': budget.warningPercent,
      });
    }
    return {'matched_count': budgets.length, 'budgets': statuses};
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
    if (query.account != null) {
      add(
        'LOWER(COALESCE(account, \'\')) LIKE ?',
        '%${query.account!.toLowerCase()}%',
      );
    }
    if (query.status != null) add('status = ?', query.status);
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
