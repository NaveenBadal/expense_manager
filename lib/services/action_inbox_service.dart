import 'dart:math' as math;

import '../models/action_item.dart';
import '../models/budget.dart';
import '../models/expense.dart';
import '../models/money_briefing.dart';

class ActionInboxService {
  const ActionInboxService._();

  static List<ActionItem> compute({
    required List<Expense> expenses,
    required List<Budget> budgets,
    required List<Map<String, dynamic>> smsAudit,
    required MoneyBriefing briefing,
    Set<String> dismissedKeys = const {},
    DateTime? today,
  }) {
    final now = today ?? DateTime.now();
    final items = <ActionItem>[
      ..._importIssues(smsAudit),
      ..._anomalies(expenses, now),
      ..._budgetPressure(expenses, budgets, now),
      ..._commitments(briefing, now),
      if (briefing.income <= 0 && briefing.spent > 0)
        ActionItem(
          key: 'planning:${now.year}-${now.month}:income',
          kind: ActionItemKind.planning,
          priority: ActionItemPriority.important,
          title: 'Complete your income picture',
          body:
              'No income is visible this month, so forecasts are intentionally cautious.',
          actionLabel: 'Review plan',
        ),
    ];
    items.removeWhere((item) => dismissedKeys.contains(item.key));
    items.sort((a, b) {
      final priority = a.priority.index.compareTo(b.priority.index);
      if (priority != 0) return priority;
      return (a.dueDate ?? DateTime(9999)).compareTo(
        b.dueDate ?? DateTime(9999),
      );
    });
    return items;
  }

  static Iterable<ActionItem> _importIssues(
    List<Map<String, dynamic>> audit,
  ) sync* {
    for (final row in audit) {
      if (row['has_expense'] == 1) continue;
      final reason = row['skip_reason'] as String? ?? '';
      if (reason != 'parse_error' &&
          reason != 'no_response' &&
          reason != 'zero_amount') {
        continue;
      }
      final id = row['id'];
      final body = row['body'] as String? ?? '';
      yield ActionItem(
        key: 'import:$id',
        kind: ActionItemKind.importIssue,
        priority: ActionItemPriority.urgent,
        title: reason == 'no_response'
            ? 'A bank message needs another try'
            : 'Check a message we could not import',
        body: body,
        actionLabel: 'Retry import',
        smsBody: body,
      );
    }
  }

  static Iterable<ActionItem> _anomalies(
    List<Expense> expenses,
    DateTime now,
  ) sync* {
    final weekStartSource = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = DateTime(
      weekStartSource.year,
      weekStartSource.month,
      weekStartSource.day,
    );
    final historyStart = weekStart.subtract(const Duration(days: 28));
    final current = <String, List<Expense>>{};
    final history = <String, double>{};
    for (final expense in expenses.where((e) => !e.isIncome)) {
      final merchant = expense.displayMerchant.trim();
      if (!expense.date.isBefore(weekStart)) {
        current.putIfAbsent(merchant, () => []).add(expense);
      } else if (expense.date.isAfter(historyStart)) {
        history.update(
          merchant,
          (value) => value + expense.amount,
          ifAbsent: () => expense.amount,
        );
      }
    }
    for (final entry in current.entries) {
      final usual = (history[entry.key] ?? 0) / 4;
      if (usual <= 0) continue;
      final total = entry.value.fold<double>(0, (sum, e) => sum + e.amount);
      if (total <= usual * 1.5) continue;
      final latest = entry.value.reduce(
        (a, b) => a.date.isAfter(b.date) ? a : b,
      );
      final multiplier = total / usual;
      yield ActionItem(
        key:
            'anomaly:${weekStart.toIso8601String()}:${entry.key.toLowerCase()}',
        kind: ActionItemKind.anomaly,
        priority: multiplier >= 2.5
            ? ActionItemPriority.urgent
            : ActionItemPriority.important,
        title: 'Unusual activity at ${entry.key}',
        body:
            'This week is ${multiplier.toStringAsFixed(1)}× your recent weekly average.',
        actionLabel: 'Review transaction',
        expenseId: latest.id,
        merchant: entry.key,
      );
    }
  }

  static Iterable<ActionItem> _budgetPressure(
    List<Expense> expenses,
    List<Budget> budgets,
    DateTime now,
  ) sync* {
    final spent = <String, double>{};
    for (final expense in expenses.where(
      (e) =>
          !e.isIncome && e.date.year == now.year && e.date.month == now.month,
    )) {
      spent.update(
        expense.category,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }
    for (final budget in budgets) {
      if (budget.limitAmount <= 0) continue;
      final ratio = (spent[budget.category] ?? 0) / budget.limitAmount;
      if (ratio < .8) continue;
      yield ActionItem(
        key: 'budget:${now.year}-${now.month}:${budget.category}',
        kind: ActionItemKind.budget,
        priority: ratio >= 1
            ? ActionItemPriority.urgent
            : ActionItemPriority.important,
        title: ratio >= 1
            ? '${budget.category} is over its plan'
            : '${budget.category} is nearing its limit',
        body: '${(ratio * 100).round()}% used this month.',
        actionLabel: 'Adjust budget',
        category: budget.category,
      );
    }
  }

  static Iterable<ActionItem> _commitments(
    MoneyBriefing briefing,
    DateTime now,
  ) sync* {
    for (final commitment in briefing.upcomingCommitments) {
      final days = math.max(
        0,
        DateTime(
          commitment.dueDate.year,
          commitment.dueDate.month,
          commitment.dueDate.day,
        ).difference(DateTime(now.year, now.month, now.day)).inDays,
      );
      if (days > 7) continue;
      yield ActionItem(
        key:
            'commitment:${commitment.dueDate.toIso8601String()}:${commitment.merchant.toLowerCase()}',
        kind: ActionItemKind.commitment,
        priority: days <= 2
            ? ActionItemPriority.important
            : ActionItemPriority.upcoming,
        title: '${commitment.merchant} is due soon',
        body: days == 0
            ? 'Expected today and already protected in safe-to-spend.'
            : 'Expected in $days day${days == 1 ? '' : 's'} and already protected.',
        actionLabel: 'View commitment',
        merchant: commitment.merchant,
        dueDate: commitment.dueDate,
      );
    }
  }
}
