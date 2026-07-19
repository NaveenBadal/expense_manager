import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fund_flow/agent/agent_proposal.dart';
import 'package:fund_flow/features/ask/agent_approval_card.dart';
import 'package:fund_flow/ui/foundation/current_theme.dart';

AgentProposal _proposal({
  required AgentProposalKind kind,
  required String title,
  String explanation = '',
  List<int> affectedIds = const [],
  bool requiresAuthentication = false,
  bool reversible = true,
}) => AgentProposal(
  kind: kind,
  title: title,
  explanation: explanation,
  arguments: const {},
  createdAt: DateTime(2026, 7, 19),
  expiresAt: DateTime(2026, 7, 19, 1),
  affectedIds: affectedIds,
  requiresAuthentication: requiresAuthentication,
  reversible: reversible,
);

Future<void> _pump(WidgetTester tester, AgentProposal proposal,
    {VoidCallback? onApprove, VoidCallback? onReject}) => tester.pumpWidget(
  MaterialApp(
    theme: CurrentTheme.light(),
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AgentApprovalCard(
          proposal: proposal,
          onApprove: onApprove ?? () {},
          onReject: onReject ?? () {},
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('states that nothing has been applied yet', (tester) async {
    await _pump(
      tester,
      _proposal(
        kind: AgentProposalKind.bulkCategory,
        title: 'Recategorise 2 transactions as Food',
        explanation: 'Both were paid to a restaurant.',
        affectedIds: const [1, 2],
      ),
    );

    expect(find.text('Needs your approval'), findsOneWidget);
    expect(find.text('Recategorise 2 transactions as Food'), findsOneWidget);
    // The agent must never leave the impression a change already happened.
    expect(
      find.textContaining('Nothing has changed yet.'),
      findsOneWidget,
    );
    expect(find.textContaining('2 records are affected.'), findsOneWidget);
    expect(find.textContaining('This can be undone.'), findsOneWidget);
  });

  testWidgets('never claims an irreversible change can be undone', (
    tester,
  ) async {
    await _pump(
      tester,
      _proposal(
        kind: AgentProposalKind.setAppLock,
        title: 'Turn on app lock',
        requiresAuthentication: true,
        reversible: false,
      ),
    );

    expect(find.text('Approve securely'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    expect(find.textContaining('This can be undone.'), findsNothing);
  });

  testWidgets('singular wording for a single affected record', (tester) async {
    await _pump(
      tester,
      _proposal(
        kind: AgentProposalKind.deleteTransaction,
        title: 'Delete one transaction',
        affectedIds: const [7],
      ),
    );
    expect(find.textContaining('One record is affected.'), findsOneWidget);
  });

  testWidgets('approve and reject each fire once', (tester) async {
    var approved = 0;
    var rejected = 0;
    await _pump(
      tester,
      _proposal(
        kind: AgentProposalKind.bulkCategory,
        title: 'Recategorise',
        affectedIds: const [1],
      ),
      onApprove: () => approved++,
      onReject: () => rejected++,
    );

    await tester.tap(find.text('Reject'));
    await tester.pump();
    expect(rejected, 1);
    expect(approved, 0);

    await tester.tap(find.text('Approve'));
    await tester.pump();
    expect(approved, 1);
  });
}
