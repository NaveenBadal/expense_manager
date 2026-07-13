import 'package:expense_manager/models/budget.dart';
import 'package:expense_manager/models/expense.dart';
import 'package:expense_manager/models/money_briefing.dart';
import 'package:expense_manager/models/savings_goal.dart';
import 'package:expense_manager/services/money_briefing_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Expense expense({
    required double amount,
    required DateTime date,
    String merchant = 'Shop',
    String category = 'Shopping',
    String type = 'expense',
    bool recurring = false,
  }) => Expense(
    amount: amount,
    currency: 'INR',
    merchant: merchant,
    category: category,
    date: date,
    originalSms: '',
    type: type,
    isRecurring: recurring,
  );

  test('protects an upcoming recurring bill from safe-to-spend', () {
    final items = [
      expense(
        amount: 50000,
        date: DateTime(2026, 7, 1),
        merchant: 'Salary',
        type: 'income',
      ),
      expense(amount: 10000, date: DateTime(2026, 7, 3)),
      expense(
        amount: 999,
        date: DateTime(2026, 5, 20),
        merchant: 'Stream+',
        recurring: true,
      ),
      expense(
        amount: 999,
        date: DateTime(2026, 6, 20),
        merchant: 'Stream+',
        recurring: true,
      ),
    ];

    final result = MoneyBriefingService.compute(
      expenses: items,
      budgets: const [],
      goals: const [],
      today: DateTime(2026, 7, 13),
    );

    expect(result.upcomingCommitments, hasLength(1));
    expect(result.upcomingCommitments.single.dueDate, DateTime(2026, 7, 21));
    expect(result.commitmentsTotal, 999);
    expect(result.safeToSpend, 39001);
    expect(result.nextMove.type, MoneyMoveType.protectBills);
  });

  test('protects deadline goal contribution and flags budget pressure', () {
    final result = MoneyBriefingService.compute(
      expenses: [
        expense(
          amount: 30000,
          date: DateTime(2026, 7, 1),
          merchant: 'Salary',
          type: 'income',
        ),
        expense(amount: 8500, date: DateTime(2026, 7, 5), category: 'Food'),
      ],
      budgets: const [Budget(category: 'Food', limitAmount: 10000)],
      goals: [
        SavingsGoal(
          name: 'Trip',
          targetAmount: 12000,
          currentAmount: 6000,
          deadline: DateTime(2026, 9, 13),
          colorValue: 0xFF000000,
        ),
      ],
      today: DateTime(2026, 7, 13),
    );

    expect(result.goalReserve, 2000);
    expect(result.safeToSpend, 19500);
    expect(result.pressuredCategories, ['Food']);
    expect(result.nextMove.type, MoneyMoveType.slowCategory);
  });

  test('never presents a negative safe-to-spend amount', () {
    final result = MoneyBriefingService.compute(
      expenses: [expense(amount: 2000, date: DateTime(2026, 7, 2))],
      budgets: const [],
      goals: const [],
      today: DateTime(2026, 7, 13),
    );

    expect(result.safeToSpend, 0);
    expect(result.dailySafeToSpend, 0);
    expect(result.nextMove.type, MoneyMoveType.reviewPlan);
  });

  test('uses an optional income plan and protects the safety buffer', () {
    final result = MoneyBriefingService.compute(
      expenses: [expense(amount: 2000, date: DateTime(2026, 7, 2))],
      budgets: const [],
      goals: const [],
      plannedIncome: 30000,
      safetyBuffer: 5000,
      today: DateTime(2026, 7, 13),
    );

    expect(result.income, 30000);
    expect(result.safetyBuffer, 5000);
    expect(result.safeToSpend, 23000);
  });
}
