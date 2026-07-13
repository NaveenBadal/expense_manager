class UpcomingCommitment {
  const UpcomingCommitment({
    required this.merchant,
    required this.category,
    required this.amount,
    required this.currency,
    required this.dueDate,
  });

  final String merchant;
  final String category;
  final double amount;
  final String currency;
  final DateTime dueDate;
}

enum MoneyMoveType {
  protectBills,
  fundGoal,
  slowCategory,
  reviewPlan,
  stayCourse,
}

class MoneyMove {
  const MoneyMove({
    required this.type,
    required this.title,
    required this.body,
  });

  final MoneyMoveType type;
  final String title;
  final String body;
}

class MoneyBriefing {
  const MoneyBriefing({
    required this.income,
    required this.spent,
    required this.safeToSpend,
    required this.dailySafeToSpend,
    required this.upcomingCommitments,
    required this.commitmentsTotal,
    required this.goalReserve,
    required this.safetyBuffer,
    required this.projectedMonthSpend,
    required this.pressuredCategories,
    required this.nextMove,
  });

  final double income;
  final double spent;
  final double safeToSpend;
  final double dailySafeToSpend;
  final List<UpcomingCommitment> upcomingCommitments;
  final double commitmentsTotal;
  final double goalReserve;
  final double safetyBuffer;
  final double projectedMonthSpend;
  final List<String> pressuredCategories;
  final MoneyMove nextMove;

  bool get isOnTrack => income <= 0 || projectedMonthSpend <= income;
}
