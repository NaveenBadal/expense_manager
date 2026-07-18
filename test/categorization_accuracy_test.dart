import 'package:expense_manager/services/categorization_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SMS extraction guards', () {
    test('accepts an amount explicitly present with Indian grouping', () {
      expect(
        smsContainsAmount(
          'INR 1,24,500.75 debited from account ending 2048',
          124500.75,
        ),
        isTrue,
      );
    });

    test('rejects an invented amount', () {
      expect(
        smsContainsAmount('INR 899.00 paid. Balance INR 20,410.00', 999),
        isFalse,
      );
    });

    test('detects direct direction contradictions', () {
      expect(
        smsSupportsDirection('INR 500 credited to your account', 'expense'),
        isFalse,
      );
      expect(
        smsSupportsDirection('INR 500 debited from your account', 'income'),
        isFalse,
      );
      expect(
        smsSupportsDirection('You paid INR 500 to ACME', 'expense'),
        isTrue,
      );
    });
  });
}
