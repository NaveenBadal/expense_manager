import 'dart:io';

import 'package:expense_manager/models/assistant_message.dart';
import 'package:expense_manager/models/agent_artifact.dart';
import 'package:expense_manager/models/budget.dart';
import 'package:expense_manager/models/expense.dart';
import 'package:expense_manager/models/transaction_query.dart';
import 'package:expense_manager/services/database_helper.dart';
import 'package:expense_manager/services/local_money_mcp.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory databaseDirectory;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    databaseDirectory = await Directory.systemTemp.createTemp(
      'expense-manager-database-test-',
    );
    await databaseFactory.setDatabasesPath(databaseDirectory.path);
  });

  tearDownAll(() async {
    await DatabaseHelper.instance.close();
    await databaseDirectory.delete(recursive: true);
  });

  test(
    'persists conversations and aggregates filtered transactions in SQL',
    () async {
      final database = DatabaseHelper.instance;
      await database.insertExpenses([
        Expense(
          amount: 200,
          currency: 'INR',
          merchant: 'Cafe One',
          category: 'Food',
          date: DateTime(2026, 6, 20, 9),
          originalSms:
              'INR 200 debited from account at BLUE TOKAI on 20-06-2026.',
        ),
        Expense(
          amount: 300,
          currency: 'INR',
          merchant: 'Cafe Two',
          category: 'Food',
          date: DateTime(2026, 6, 20, 18),
          originalSms: '',
        ),
        Expense(
          amount: 999,
          currency: 'INR',
          merchant: 'Other day',
          category: 'Shopping',
          date: DateTime(2026, 6, 21),
          originalSms: '',
        ),
      ]);

      final summary = await database.summarizeTransactions(
        TransactionQuery(
          from: DateTime(2026, 6, 20),
          to: DateTime(2026, 6, 20, 23, 59, 59, 999, 999),
        ),
      );
      expect(summary['matched_count'], 2);
      expect(
        ((summary['totals_by_currency'] as Map)['INR'] as Map)['expense'],
        500,
      );

      final matching = await database.queryTransactions(
        const TransactionQuery(category: 'Food'),
      );
      final transactionId = matching
          .firstWhere((transaction) => transaction.merchant == 'Cafe One')
          .id!;
      final mcp = LocalMoneyMcpClient(LocalMoneyMcpServer(database));
      final limited = await mcp.callTool('search_transactions', {
        'category': 'Food',
        'limit': 1,
      });
      expect(limited.structuredContent['matched_count'], 2);
      expect(limited.structuredContent['records_truncated'], isTrue);
      expect(limited.structuredContent['records'], hasLength(1));

      final breakdown = await mcp.callTool('spending_breakdown', {
        'group_by': 'category',
      });
      expect(breakdown.isError, isFalse);
      expect(breakdown.structuredContent['groups'], isNotEmpty);

      final comparison = await mcp.callTool('compare_periods', {
        'first': {'from': '2026-06-20T00:00:00', 'to': '2026-06-20T23:59:59'},
        'second': {'from': '2026-06-21T00:00:00', 'to': '2026-06-21T23:59:59'},
      });
      expect(comparison.isError, isFalse);
      expect(comparison.structuredContent['matched_count'], 3);

      final budgetId = await database.insertBudget(
        Budget(
          name: 'Food',
          amount: 1000,
          currency: 'INR',
          category: 'Food',
          createdAt: DateTime(2026, 6, 1),
        ),
      );
      expect(budgetId, greaterThan(0));
      final budgets = await mcp.callTool('get_budget_status', {});
      expect(budgets.structuredContent['budgets'], hasLength(1));

      final source = await mcp.callTool('reanalyze_transaction_sms', {
        'id': transactionId,
      });
      expect(source.isError, isFalse);
      expect(source.structuredContent['original_sms'], contains('BLUE TOKAI'));

      final correction = await mcp.callTool('update_transaction', {
        'id': transactionId,
        'category': 'Dining',
      });
      expect(correction.isError, isFalse);
      final corrected = await database.getExpenseById(transactionId);
      expect(corrected?.category, 'Dining');
      final undone = await mcp.callTool('undo_last_change', {});
      expect(undone.structuredContent['changed'], isTrue);
      expect((await database.getExpenseById(transactionId))?.category, 'Food');

      final bulk = await mcp.callTool('bulk_update_transactions', {
        'filter': {'category': 'Food'},
        'changes': {'category': 'Dining'},
      });
      expect(bulk.structuredContent['changed_count'], 2);
      expect(
        await database.queryTransactions(
          const TransactionQuery(category: 'Dining'),
        ),
        hasLength(2),
      );
      await mcp.callTool('undo_last_change', {});
      expect(
        await database.queryTransactions(
          const TransactionQuery(category: 'Food'),
        ),
        hasLength(2),
      );

      final remembered = await mcp.callTool('remember_preference', {
        'key': 'coffee merchants',
        'value': 'Blue Tokai and Starbucks',
      });
      expect(remembered.structuredContent['changed'], isTrue);
      final memory = await mcp.callTool('get_agent_memory', {});
      expect(memory.structuredContent['memories'], hasLength(1));

      await database.insertAssistantMessage(
        AssistantMessage(
          user: true,
          text: 'What happened on 20 June?',
          timestamp: DateTime(2026, 7, 16),
          artifactJson: const AgentArtifact(
            kind: AgentArtifactKind.summary,
            title: 'Verified total',
          ).encode(),
        ),
      );
      final messages = await database.getAssistantMessages();
      expect(messages.single.text, 'What happened on 20 June?');
      expect(
        AgentArtifact.decode(messages.single.artifactJson).kind,
        AgentArtifactKind.summary,
      );
    },
  );
}
