enum ActionItemKind { importIssue, anomaly, budget, commitment, planning }

enum ActionItemPriority { urgent, important, upcoming }

class ActionItem {
  const ActionItem({
    required this.key,
    required this.kind,
    required this.priority,
    required this.title,
    required this.body,
    required this.actionLabel,
    this.expenseId,
    this.smsBody,
    this.merchant,
    this.category,
    this.dueDate,
  });

  final String key;
  final ActionItemKind kind;
  final ActionItemPriority priority;
  final String title;
  final String body;
  final String actionLabel;
  final int? expenseId;
  final String? smsBody;
  final String? merchant;
  final String? category;
  final DateTime? dueDate;
}
