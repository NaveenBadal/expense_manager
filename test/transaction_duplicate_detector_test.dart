import 'package:expense_manager/models/expense.dart';
import 'package:expense_manager/services/transaction_duplicate_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const detector = TransactionDuplicateDetector();
  final time = DateTime(2026, 7, 15, 12);

  Expense expense({
    required String merchant,
    required String sms,
    double amount = 499,
    Duration offset = Duration.zero,
  }) => Expense(
    amount: amount,
    currency: 'INR',
    merchant: merchant,
    category: 'Shopping',
    date: time.add(offset),
    originalSms: sms,
  );

  test('recognizes differently worded alerts for one payment', () {
    final first = expense(
      merchant: 'AMAZON',
      sms: 'INR 499 paid to Amazon. UPI ref 619633842119',
    );
    final second = expense(
      merchant: 'Amazon India',
      sms: 'A/c debited Rs.499 at AMAZON. Ref 619633842119',
      offset: const Duration(minutes: 1),
    );
    expect(detector.isDuplicate(second, first), isTrue);
  });

  test('keeps separate purchases with same amount apart', () {
    final first = expense(merchant: 'Cafe One', sms: 'Paid Cafe One');
    final second = expense(
      merchant: 'Metro Card',
      sms: 'Paid Metro Card',
      offset: const Duration(minutes: 8),
    );
    expect(detector.isDuplicate(second, first), isFalse);
  });

  test('never merges different amounts', () {
    expect(
      detector.isDuplicate(
        expense(merchant: 'Amazon', sms: 'ref 12345678', amount: 500),
        expense(merchant: 'Amazon', sms: 'ref 12345678', amount: 499),
      ),
      isFalse,
    );
  });
}
