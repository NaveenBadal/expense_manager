import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../agent/agent_proposal.dart';
import '../agent/agent_runner.dart';
import '../domain/conversation.dart';
import '../domain/transaction.dart';
import '../ingestion/ai_message_ingestion.dart';

class FundFlowStore {
  FundFlowStore({Database? database}) : _database = database;
  Database? _database;
  static const schemaVersion = 2;

  Future<Database> get database async => _database ??= await openDatabase(
    path.join(await getDatabasesPath(), 'fund_flow_greenfield.db'),
    version: schemaVersion,
    onCreate: (db, _) async {
      await db.execute(
        '''CREATE TABLE transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount_minor INTEGER NOT NULL, currency TEXT NOT NULL,
        direction TEXT NOT NULL, merchant TEXT NOT NULL,
        category TEXT NOT NULL, occurred_at TEXT NOT NULL,
        source TEXT NOT NULL, review_state TEXT NOT NULL,
        confidence REAL NOT NULL, account TEXT, note TEXT, source_text TEXT)''',
      );
      await db.execute('''CREATE TABLE conversation(
        id INTEGER PRIMARY KEY AUTOINCREMENT, author TEXT NOT NULL,
        text TEXT NOT NULL, created_at TEXT NOT NULL, verified INTEGER NOT NULL,
        supporting_ids TEXT NOT NULL, parts_json TEXT NOT NULL DEFAULT '[]',
        unstructured INTEGER NOT NULL DEFAULT 0)''');
      await db.execute('''CREATE TABLE preferences(
        key TEXT PRIMARY KEY, value TEXT NOT NULL)''');
      await db.execute('''CREATE TABLE import_attempts(
        id INTEGER PRIMARY KEY AUTOINCREMENT, fingerprint TEXT UNIQUE NOT NULL,
        received_at TEXT NOT NULL, outcome TEXT NOT NULL, detail TEXT)''');
      await db.execute('''CREATE TABLE undo_records(
        id INTEGER PRIMARY KEY AUTOINCREMENT, kind TEXT NOT NULL,
        payload TEXT NOT NULL, created_at TEXT NOT NULL)''');
      await _createAgentTables(db);
    },
    onUpgrade: (db, oldVersion, _) async {
      if (oldVersion < 2) {
        await db.execute(
          "ALTER TABLE conversation ADD COLUMN parts_json TEXT NOT NULL DEFAULT '[]'",
        );
        await db.execute(
          'ALTER TABLE conversation ADD COLUMN unstructured INTEGER NOT NULL DEFAULT 0',
        );
        await _createAgentTables(db);
      }
    },
  );

  static Future<void> _createAgentTables(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS agent_proposals(
      id INTEGER PRIMARY KEY AUTOINCREMENT, kind TEXT NOT NULL,
      title TEXT NOT NULL, explanation TEXT NOT NULL,
      arguments_json TEXT NOT NULL, affected_ids TEXT NOT NULL,
      created_at TEXT NOT NULL, expires_at TEXT NOT NULL,
      requires_authentication INTEGER NOT NULL, reversible INTEGER NOT NULL,
      status TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS tool_calls(
      id INTEGER PRIMARY KEY AUTOINCREMENT, conversation_id INTEGER,
      tool TEXT NOT NULL, summary TEXT NOT NULL, is_error INTEGER NOT NULL,
      created_at TEXT NOT NULL)''');
  }

  Future<List<MoneyTransaction>> transactions() async {
    final db = await database;
    final rows = await db.query('transactions', orderBy: 'occurred_at DESC');
    return rows.map(MoneyTransaction.fromMap).toList();
  }

  Future<int> saveTransaction(MoneyTransaction value) async {
    final db = await database;
    final map = value.toMap()..remove('id');
    if (value.id == null) return db.insert('transactions', map);
    await db.update(
      'transactions',
      map,
      where: 'id = ?',
      whereArgs: [value.id],
    );
    return value.id!;
  }

  Future<void> deleteTransaction(int id) async {
    final db = await database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ConversationMessage>> conversation() async {
    final db = await database;
    final rows = await db.query('conversation', orderBy: 'created_at ASC');
    return rows.map(ConversationMessage.fromMap).toList();
  }

  Future<int> addMessage(ConversationMessage value) async {
    final db = await database;
    final map = value.toMap()..remove('id');
    return db.insert('conversation', map);
  }

  Future<void> recordToolEvents(
    int conversationId,
    Iterable<AgentToolEvent> events,
  ) async {
    final db = await database;
    final batch = db.batch();
    for (final event in events) {
      batch.insert('tool_calls', {
        'conversation_id': conversationId,
        'tool': event.tool,
        'summary': event.summary,
        'is_error': event.isError ? 1 : 0,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
    await batch.commit(noResult: true);
  }

  Future<AgentProposal> saveProposal(AgentProposal value) async {
    final id = await (await database).insert('agent_proposals', {
      'kind': value.kind.name,
      'title': value.title,
      'explanation': value.explanation,
      'arguments_json': jsonEncode(value.arguments),
      'affected_ids': value.affectedIds.join(','),
      'created_at': value.createdAt.toUtc().toIso8601String(),
      'expires_at': value.expiresAt.toUtc().toIso8601String(),
      'requires_authentication': value.requiresAuthentication ? 1 : 0,
      'reversible': value.reversible ? 1 : 0,
      'status': value.status.name,
    });
    return value.copyWith(id: id);
  }

  Future<void> setProposalStatus(int id, AgentProposalStatus status) async {
    await (await database).update(
      'agent_proposals',
      {'status': status.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> saveUndo(String kind, Map<String, Object?> payload) async {
    await (await database).insert('undo_records', {
      'kind': kind,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> applyTransactionChanges({
    required Iterable<MoneyTransaction> upserts,
    required Iterable<int> deletes,
    required String undoKind,
    required Map<String, Object?> undoPayload,
  }) async {
    final db = await database;
    await db.transaction((transaction) async {
      final createdIds = <int>[];
      for (final value in upserts) {
        final map = value.toMap()..remove('id');
        if (value.id == null) {
          createdIds.add(await transaction.insert('transactions', map));
        } else {
          final count = await transaction.update(
            'transactions',
            map,
            where: 'id = ?',
            whereArgs: [value.id],
          );
          if (count != 1) throw StateError('A transaction became stale.');
        }
      }
      for (final id in deletes) {
        final count = await transaction.delete(
          'transactions',
          where: 'id = ?',
          whereArgs: [id],
        );
        if (count != 1) throw StateError('A transaction became stale.');
      }
      await transaction.insert('undo_records', {
        'kind': undoKind,
        'payload': jsonEncode({
          ...undoPayload,
          if (createdIds.isNotEmpty) 'createdIds': createdIds,
        }),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    });
  }

  Future<UndoRecord?> latestUndo() async {
    final rows = await (await database).query(
      'undo_records',
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return UndoRecord(
      id: row['id'] as int,
      kind: row['kind'] as String,
      payload: Map<String, Object?>.from(
        jsonDecode(row['payload'] as String) as Map,
      ),
    );
  }

  Future<void> applyTransactionUndo(UndoRecord record) async {
    final db = await database;
    await db.transaction((transaction) async {
      switch (record.kind) {
        case 'delete_created_transaction':
          for (final id
              in (record.payload['createdIds'] as List? ?? const [])) {
            await transaction.delete(
              'transactions',
              where: 'id = ?',
              whereArgs: [(id as num).toInt()],
            );
          }
        case 'restore_transaction':
          final value = Map<String, Object?>.from(
            record.payload['transaction'] as Map,
          );
          await transaction.insert(
            'transactions',
            value,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        case 'restore_transactions':
          for (final raw
              in record.payload['transactions'] as List? ?? const []) {
            await transaction.insert(
              'transactions',
              Map<String, Object?>.from(raw as Map),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        default:
          throw StateError('This undo record is not a transaction change.');
      }
      await transaction.delete(
        'undo_records',
        where: 'id = ?',
        whereArgs: [record.id],
      );
    });
  }

  Future<void> consumeUndo(int id) async {
    await (await database).delete(
      'undo_records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearConversation() async =>
      (await database).delete('conversation');

  Future<Set<String>> seenImportFingerprints(Iterable<String> values) async {
    final fingerprints = values.toList();
    if (fingerprints.isEmpty) return {};
    final placeholders = List.filled(fingerprints.length, '?').join(',');
    final rows = await (await database).query(
      'import_attempts',
      columns: ['fingerprint'],
      where: 'fingerprint IN ($placeholders)',
      whereArgs: fingerprints,
    );
    return rows.map((row) => row['fingerprint'] as String).toSet();
  }

  Future<int> commitIngestionBatch(AiIngestionBatch batch) async {
    final db = await database;
    return db.transaction((transaction) async {
      var imported = 0;
      for (final result in batch.results) {
        final accepted = await transaction.insert('import_attempts', {
          'fingerprint': result.fingerprint,
          'received_at': DateTime.now().toUtc().toIso8601String(),
          'outcome': result.decision.name,
          'detail': result.reason,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        if (accepted == 0 || result.transaction == null) continue;
        final value = result.transaction!.toMap()..remove('id');
        await transaction.insert('transactions', value);
        imported++;
      }
      return imported;
    });
  }

  Future<String?> preference(String key) async {
    final rows = await (await database).query(
      'preferences',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setPreference(String key, String value) async =>
      (await database).insert('preferences', {
        'key': key,
        'value': value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}

class UndoRecord {
  const UndoRecord({
    required this.id,
    required this.kind,
    required this.payload,
  });
  final int id;
  final String kind;
  final Map<String, Object?> payload;
}
