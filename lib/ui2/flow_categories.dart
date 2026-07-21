import '../domain/transaction.dart';

/// The category vocabulary offered wherever a category can be corrected.
///
/// Two lists, split by direction: money leaving and money arriving are
/// categorised differently — a refund or salary is never "Food". The same
/// vocabulary is shared by Review, Activity, the editor and chat inline
/// actions, so a correction made anywhere offers the same choices. Order is by
/// how often a category is the right answer, because these render as chips and
/// the likely fix should be within thumb reach.
const List<String> kFlowExpenseCategories = [
  'Food',
  'Groceries',
  'Transport',
  'Shopping',
  'Bills',
  'Health',
  'Entertainment',
  'Subscriptions',
  'Transfer',
  'Other',
];

/// Categories offered for money arriving. "Income" leads as the safe default.
const List<String> kFlowIncomeCategories = [
  'Income',
  'Salary',
  'Refund',
  'Cashback',
  'Interest',
  'Business',
  'Transfer',
  'Other',
];

/// Kept as an alias so existing expense-side call sites read unchanged.
const List<String> kFlowCategories = kFlowExpenseCategories;

/// The vocabulary for a given [direction].
List<String> categoriesFor(TransactionDirection direction) =>
    direction == TransactionDirection.incoming
    ? kFlowIncomeCategories
    : kFlowExpenseCategories;

/// A sensible default category for [direction], used when a direction change
/// leaves the current category invalid for the new side.
String defaultCategoryFor(TransactionDirection direction) =>
    direction == TransactionDirection.incoming ? 'Income' : 'Other';

/// The single direction shared by [items], or money out when they are mixed
/// (or empty). A bulk category picker uses this to offer the right vocabulary;
/// a mixed selection falls back to the expense side rather than guessing.
TransactionDirection sharedDirection(Iterable<MoneyTransaction> items) {
  final directions = items.map((item) => item.direction).toSet();
  return directions.length == 1
      ? directions.first
      : TransactionDirection.outgoing;
}
