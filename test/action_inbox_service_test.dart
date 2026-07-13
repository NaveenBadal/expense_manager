import 'package:expense_manager/models/action_item.dart';
import 'package:expense_manager/models/budget.dart';
import 'package:expense_manager/models/expense.dart';
import 'package:expense_manager/services/action_inbox_service.dart';
import 'package:expense_manager/services/money_briefing_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Expense expense({
    int? id,
    required double amount,
    required DateTime date,
    String merchant = 'Shop',
    String category = 'Shopping',
    String type = 'expense',
    bool recurring = false,
  }) => Expense(
    id: id,
    amount: amount,
    currency: 'INR',
    merchant: merchant,
    category: category,
    date: date,
    originalSms: '',
    type: type,
    isRecurring: recurring,
  );

  test('only actionable import failures enter the inbox', () {
    final briefing = MoneyBriefingService.compute(
      expenses: const [],
      budgets: const [],
      goals: const [],
      today: DateTime(2026, 7, 13),
    );
    final items = ActionInboxService.compute(
      expenses: const [],
      budgets: const [],
      briefing: briefing,
      today: DateTime(2026, 7, 13),
      smsAudit: const [
        {
          'id': 1,
          'body': 'Transaction message',
          'has_expense': 0,
          'skip_reason': 'parse_error',
        },
        {
          'id': 2,
          'body': 'Sale today',
          'has_expense': 0,
          'skip_reason': 'promotional',
        },
      ],
    );

    expect(
      items.where((item) => item.kind == ActionItemKind.importIssue),
      hasLength(1),
    );
    expect(items.first.priority, ActionItemPriority.urgent);
    expect(items.first.smsBody, 'Transaction message');
  });

  test(
    'prioritizes an exceeded budget and supports durable dismissal keys',
    () {
      final expenses = [
        expense(
          amount: 30000,
          date: DateTime(2026, 7, 1),
          merchant: 'Salary',
          type: 'income',
        ),
        expense(amount: 11000, date: DateTime(2026, 7, 5), category: 'Food'),
      ];
      const budgets = [Budget(category: 'Food', limitAmount: 10000)];
      final briefing = MoneyBriefingService.compute(
        expenses: expenses,
        budgets: budgets,
        goals: const [],
        today: DateTime(2026, 7, 13),
      );

      final items = ActionInboxService.compute(
        expenses: expenses,
        budgets: budgets,
        smsAudit: const [],
        briefing: briefing,
        today: DateTime(2026, 7, 13),
      );
      final budget = items.singleWhere(
        (item) => item.kind == ActionItemKind.budget,
      );
      expect(budget.priority, ActionItemPriority.urgent);

      final dismissed = ActionInboxService.compute(
        expenses: expenses,
        budgets: budgets,
        smsAudit: const [],
        briefing: briefing,
        dismissedKeys: {budget.key},
        today: DateTime(2026, 7, 13),
      );
      expect(
        dismissed.where((item) => item.kind == ActionItemKind.budget),
        isEmpty,
      );
    },
  );

  test('surfaces commitments only when due within seven days', () {
    final expenses = [
      expense(
        amount: 50000,
        date: DateTime(2026, 7, 1),
        merchant: 'Salary',
        type: 'income',
      ),
      expense(
        amount: 999,
        date: DateTime(2026, 5, 16),
        merchant: 'Stream+',
        recurring: true,
      ),
      expense(
        amount: 999,
        date: DateTime(2026, 6, 16),
        merchant: 'Stream+',
        recurring: true,
      ),
    ];
    final briefing = MoneyBriefingService.compute(
      expenses: expenses,
      budgets: const [],
      goals: const [],
      today: DateTime(2026, 7, 13),
    );
    final items = ActionInboxService.compute(
      expenses: expenses,
      budgets: const [],
      smsAudit: const [],
      briefing: briefing,
      today: DateTime(2026, 7, 13),
    );

    final commitment = items.singleWhere(
      (item) => item.kind == ActionItemKind.commitment,
    );
    expect(commitment.merchant, 'Stream+');
    expect(commitment.priority, ActionItemPriority.upcoming);
  });
}
