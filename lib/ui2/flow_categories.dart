/// The category vocabulary offered wherever a category can be corrected.
///
/// One list, shared by Review, Activity and (later) chat inline actions, so a
/// correction made anywhere offers the same choices. Order is by how often a
/// category is the right answer, because these render as chips and the likely
/// fix should be within thumb reach.
const List<String> kFlowCategories = [
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
