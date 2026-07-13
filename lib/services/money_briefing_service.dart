import 'dart:math' as math;

import '../models/budget.dart';
import '../models/expense.dart';
import '../models/money_briefing.dart';
import '../models/savings_goal.dart';

/// Turns ledger history into an actionable, explainable month forecast.
class MoneyBriefingService {
  const MoneyBriefingService._();

  static MoneyBriefing compute({
    required List<Expense> expenses,
    required List<Budget> budgets,
    required List<SavingsGoal> goals,
    double plannedIncome = 0,
    double safetyBuffer = 0,
    DateTime? today,
  }) {
    final sourceDate = today ?? DateTime.now();
    final now = DateTime(sourceDate.year, sourceDate.month, sourceDate.day);
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    final monthItems = expenses.where(
      (e) => e.date.year == now.year && e.date.month == now.month,
    );
    final income = monthItems
        .where((e) => e.isIncome)
        .fold<double>(0, (sum, e) => sum + e.amount);
    final effectiveIncome = income > 0 ? income : plannedIncome;
    final spent = monthItems
        .where((e) => !e.isIncome)
        .fold<double>(0, (sum, e) => sum + e.amount);
    final variableSpent = monthItems
        .where((e) => !e.isIncome && !e.isRecurring)
        .fold<double>(0, (sum, e) => sum + e.amount);

    final commitments = _upcomingCommitments(expenses, now, monthEnd);
    final commitmentsTotal = commitments.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );
    final goalReserve = _goalReserve(goals, now);
    final unprotectedBalance = effectiveIncome - spent;
    final safeToSpend = math.max(
      0.0,
      unprotectedBalance - commitmentsTotal - goalReserve - safetyBuffer,
    );
    final daysLeft = monthEnd.day - now.day + 1;
    final dailySafe = safeToSpend / math.max(1, daysLeft);

    final elapsedDays = math.max(1, now.day);
    final remainingAfterToday = math.max(0, monthEnd.day - now.day);
    final variableRunRate = variableSpent / elapsedDays;
    final projected =
        spent + commitmentsTotal + (variableRunRate * remainingAfterToday);
    final pressure = _pressuredCategories(budgets, monthItems);

    return MoneyBriefing(
      income: effectiveIncome,
      spent: spent,
      safeToSpend: safeToSpend,
      dailySafeToSpend: dailySafe,
      upcomingCommitments: commitments,
      commitmentsTotal: commitmentsTotal,
      goalReserve: goalReserve,
      safetyBuffer: safetyBuffer,
      projectedMonthSpend: projected,
      pressuredCategories: pressure,
      nextMove: _nextMove(
        commitments: commitments,
        goalReserve: goalReserve,
        pressure: pressure,
        projected: projected,
        income: effectiveIncome,
        spent: spent,
      ),
    );
  }

  static List<UpcomingCommitment> _upcomingCommitments(
    List<Expense> expenses,
    DateTime now,
    DateTime monthEnd,
  ) {
    final groups = <String, List<Expense>>{};
    for (final expense in expenses.where((e) => e.isRecurring && !e.isIncome)) {
      final key = (expense.normalizedMerchant ?? expense.merchant)
          .trim()
          .toLowerCase();
      groups.putIfAbsent(key, () => []).add(expense);
    }

    final result = <UpcomingCommitment>[];
    for (final group in groups.values) {
      if (group.length < 2) continue;
      group.sort((a, b) => a.date.compareTo(b.date));
      final gaps = <int>[];
      for (var i = 1; i < group.length; i++) {
        final gap = group[i].date.difference(group[i - 1].date).inDays.abs();
        if (gap > 0) gaps.add(gap);
      }
      if (gaps.isEmpty) continue;
      gaps.sort();
      final interval = gaps[gaps.length ~/ 2].clamp(5, 370);
      final lastDate = group.last.date;
      var due = DateTime(
        lastDate.year,
        lastDate.month,
        lastDate.day,
      ).add(Duration(days: interval));
      while (due.isBefore(now)) {
        due = due.add(Duration(days: interval));
      }
      if (due.isAfter(monthEnd)) continue;

      final recent = group.reversed.take(math.min(3, group.length));
      final average =
          recent.fold<double>(0, (sum, e) => sum + e.amount) / recent.length;
      final last = group.last;
      result.add(
        UpcomingCommitment(
          merchant: last.displayMerchant,
          category: last.category,
          amount: average,
          currency: last.currency,
          dueDate: due,
        ),
      );
    }
    result.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return result;
  }

  static double _goalReserve(List<SavingsGoal> goals, DateTime now) {
    return goals
        .where((goal) => !goal.isCompleted && goal.deadline != null)
        .fold(0, (sum, goal) {
          final remaining = math.max(0, goal.targetAmount - goal.currentAmount);
          final days = math.max(1, goal.deadline!.difference(now).inDays);
          final months = math.max(1, (days / 30).ceil());
          return sum + remaining / months;
        });
  }

  static List<String> _pressuredCategories(
    List<Budget> budgets,
    Iterable<Expense> monthItems,
  ) {
    final spentByCategory = <String, double>{};
    for (final expense in monthItems.where((e) => !e.isIncome)) {
      spentByCategory.update(
        expense.category,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }
    final result = budgets
        .where(
          (budget) =>
              budget.limitAmount > 0 &&
              (spentByCategory[budget.category] ?? 0) / budget.limitAmount >=
                  .8,
        )
        .map((budget) => budget.category)
        .toList();
    result.sort();
    return result;
  }

  static MoneyMove _nextMove({
    required List<UpcomingCommitment> commitments,
    required double goalReserve,
    required List<String> pressure,
    required double projected,
    required double income,
    required double spent,
  }) {
    if (pressure.isNotEmpty) {
      final category = pressure.first;
      return MoneyMove(
        type: MoneyMoveType.slowCategory,
        title: 'Ease up on $category',
        body: pressure.length == 1
            ? 'This budget has crossed 80%. A lighter few days keeps the month comfortable.'
            : '$category and ${pressure.length - 1} more budgets have crossed 80%.',
      );
    }
    if (commitments.isNotEmpty) {
      final next = commitments.first;
      return MoneyMove(
        type: MoneyMoveType.protectBills,
        title: '${next.merchant} is coming up',
        body: 'It is already protected in your safe-to-spend number.',
      );
    }
    if (goalReserve > 0) {
      return const MoneyMove(
        type: MoneyMoveType.fundGoal,
        title: 'Your goal contribution is protected',
        body: 'Move it to savings when convenient and stay on schedule.',
      );
    }
    if (income <= 0 && spent > 0) {
      return const MoneyMove(
        type: MoneyMoveType.reviewPlan,
        title: 'Add your income picture',
        body:
            'No income is visible this month, so your safe-to-spend stays cautious.',
      );
    }
    if (income > 0 && projected > income) {
      return const MoneyMove(
        type: MoneyMoveType.slowCategory,
        title: 'A small reset will help',
        body: 'Your current pace may outrun this month’s income.',
      );
    }
    return const MoneyMove(
      type: MoneyMoveType.stayCourse,
      title: 'You are clear for today',
      body: 'No urgent money task needs your attention.',
    );
  }
}
