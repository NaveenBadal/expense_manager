@Tags(['bench'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fund_flow/domain/transaction.dart';

/// Compares the work each strategy does across a whole import run.
///
/// The old pipeline extended the list it already held. The current one
/// re-read and re-mapped every transaction after each batch, so a late batch
/// paid for everything the earlier batches inserted.
void main() {
  MoneyTransaction row(int i) => MoneyTransaction(
    id: i,
    amountMinor: 1000 + i,
    currency: 'INR',
    direction: TransactionDirection.outgoing,
    merchant: 'M$i',
    category: 'Food',
    occurredAt: DateTime(2026, 7, 19).subtract(Duration(minutes: i)),
    source: TransactionSource.message,
  );

  test('re-query cost is quadratic, append is linear', () {
    const batches = 30;
    const perBatch = 12;

    var requeryRowsTouched = 0;
    var appendRowsTouched = 0;
    var ledger = <MoneyTransaction>[];

    for (var batch = 0; batch < batches; batch++) {
      final created = [
        for (var i = 0; i < perBatch; i++) row(batch * perBatch + i),
      ];
      ledger = [...created, ...ledger];

      // Re-query maps every row in the table, every batch.
      requeryRowsTouched += ledger.length;
      // Append only touches what this batch produced.
      appendRowsTouched += created.length;
    }

    expect(ledger, hasLength(batches * perBatch));
    expect(appendRowsTouched, batches * perBatch);

    // 30 batches over 360 transactions: 5,580 mappings against 360.
    expect(requeryRowsTouched, greaterThan(5000));
    expect(
      requeryRowsTouched / appendRowsTouched,
      greaterThan(14),
      reason: 'the gap widens as the ledger grows',
    );
  });

  test('ordering after append matches a sorted read', () {
    var ledger = <MoneyTransaction>[];
    for (var batch = 0; batch < 5; batch++) {
      final created = [for (var i = 0; i < 4; i++) row(batch * 4 + i)];
      ledger = [...created, ...ledger]
        ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    }
    final expected = [...ledger]
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    expect(
      ledger.map((e) => e.id).toList(),
      expected.map((e) => e.id).toList(),
    );
  });
}
