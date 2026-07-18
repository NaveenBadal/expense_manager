import 'package:fund_flow/domain/finance_summary.dart';
import 'package:fund_flow/domain/preferences.dart';
import 'package:fund_flow/app/app_state.dart';
import 'package:fund_flow/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI-first default uses the intended Ollama cloud model', () {
    expect(const AppPreferences().aiModel, 'gpt-oss:20b-cloud');
  });
  test('a lifecycle-paused import remains active and stoppable', () {
    const status = ImportStatus(
      phase: ImportPhase.paused,
      checked: 12,
      imported: 3,
      skipped: 9,
      message: 'Paused safely',
    );
    expect(status.working, isTrue);
    expect(status.retryable, isFalse);
    expect(status.checked, 12);
  });
  test('finance engine never combines currencies', () {
    final now = DateTime(2026, 7, 18);
    final values = [
      MoneyTransaction(
        amountMinor: 10000,
        currency: 'INR',
        direction: TransactionDirection.incoming,
        merchant: 'Employer',
        category: 'Income',
        occurredAt: now,
        source: TransactionSource.message,
      ),
      MoneyTransaction(
        amountMinor: 2500,
        currency: 'INR',
        direction: TransactionDirection.outgoing,
        merchant: 'Market',
        category: 'Food',
        occurredAt: now,
        source: TransactionSource.manual,
      ),
      MoneyTransaction(
        amountMinor: 500,
        currency: 'USD',
        direction: TransactionDirection.outgoing,
        merchant: 'Service',
        category: 'Bills',
        occurredAt: now,
        source: TransactionSource.message,
      ),
    ];
    final result = FinanceEngine.summarize(values);
    expect(result, hasLength(2));
    expect(result.first.currency, 'INR');
    expect(result.first.netMinor, 7500);
    expect(result.last.netMinor, -500);
  });
}
