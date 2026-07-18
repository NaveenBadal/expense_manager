import 'package:fund_flow/agent/agent_presentation.dart';
import 'package:fund_flow/domain/transaction.dart';
import 'package:fund_flow/features/ask/agent_answer_view.dart';
import 'package:fund_flow/ui/foundation/current_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('rich agent parts remain usable at 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final transaction = MoneyTransaction(
      id: 9,
      amountMinor: 24000,
      currency: 'INR',
      direction: TransactionDirection.outgoing,
      merchant: 'River Cafe',
      category: 'Food',
      occurredAt: DateTime(2026, 7, 18),
      source: TransactionSource.message,
    );
    String? followUp;
    MoneyTransaction? opened;
    await tester.pumpWidget(
      MaterialApp(
        theme: CurrentTheme.dark(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: AgentAnswerView(
                parts: const [
                  AgentPart(
                    kind: AgentPartKind.conclusion,
                    data: {'text': 'Food led your spending.'},
                  ),
                  AgentPart(
                    kind: AgentPartKind.metricRow,
                    data: {
                      'metrics': [
                        {
                          'label': 'Spent',
                          'amountMinor': 24000,
                          'currency': 'INR',
                        },
                      ],
                    },
                  ),
                  AgentPart(
                    kind: AgentPartKind.breakdown,
                    data: {
                      'title': 'By category',
                      'rows': [
                        {
                          'label': 'Food',
                          'amountMinor': 24000,
                          'currency': 'INR',
                        },
                      ],
                    },
                  ),
                  AgentPart(
                    kind: AgentPartKind.transactionList,
                    data: {
                      'transactionIds': [9],
                    },
                  ),
                  AgentPart(
                    kind: AgentPartKind.insight,
                    data: {'text': 'One purchase explains the total.'},
                  ),
                  AgentPart(
                    kind: AgentPartKind.sourceNote,
                    data: {'text': 'Calculated from one local transaction.'},
                  ),
                  AgentPart(
                    kind: AgentPartKind.followUps,
                    data: {
                      'questions': ['Compare with last month'],
                    },
                  ),
                ],
                transactions: [transaction],
                onFollowUp: (value) => followUp = value,
                onTransaction: (value) => opened = value,
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Compare with last month'));
    await tester.tap(find.text('Compare with last month'));
    expect(followUp, 'Compare with last month');
    await tester.ensureVisible(find.text('River Cafe'));
    await tester.tap(find.text('River Cafe'));
    expect(opened?.id, 9);
  });
}
