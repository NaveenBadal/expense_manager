import 'package:flutter_test/flutter_test.dart';
import 'package:fund_flow/agent/agent_presentation.dart';

void main() {
  test('lifts part objects out of a described compose call', () {
    // Shape observed on device: the provider wrote headings with the part
    // objects beneath them as fenced JSON instead of calling the capability.
    const content = '''
## Conclusion
This month you spent 362763.42 rupees across 57 outgoing transactions.

## MetricRow
```json
{"type":"metricRow","metrics":[{"label":"Spent","amountMinor":36276342,"currency":"INR"}]}
```

## Breakdown – By category
```json
{"type":"breakdown","title":"By category","rows":[{"label":"Bills","amountMinor":12500000,"currency":"INR"}]}
```
''';

    final presentation = AgentPresentation.tryFromLooseContent(content);
    expect(presentation, isNotNull);

    final kinds = presentation!.parts.map((part) => part.kind).toList();
    expect(kinds, contains(AgentPartKind.metricRow));
    expect(kinds, contains(AgentPartKind.breakdown));

    // Prose ahead of the JSON becomes the conclusion, and the bare "Conclusion"
    // heading is not mistaken for the answer.
    final conclusion = presentation.parts.firstWhere(
      (part) => part.kind == AgentPartKind.conclusion,
    );
    expect(conclusion.data['text'], contains('57 outgoing transactions'));
    expect(conclusion.data['text'], isNot(equals('Conclusion')));
  });

  test('does not duplicate parts found at several brace offsets', () {
    const content = '''
Spending summary.
{"type":"metricRow","metrics":[{"label":"Spent","amountMinor":100,"currency":"INR"}]}
''';
    final presentation = AgentPresentation.tryFromLooseContent(content);
    final metrics = presentation!.parts
        .where((part) => part.kind == AgentPartKind.metricRow)
        .toList();
    expect(metrics, hasLength(1));
  });

  test('still prefers the proper wrapper shape when present', () {
    const content =
        '{"parts":[{"type":"conclusion","text":"You spent less."}]}';
    final presentation = AgentPresentation.tryFromLooseContent(content);
    expect(presentation!.parts.single.kind, AgentPartKind.conclusion);
  });

  test('returns null for ordinary prose with no parts', () {
    expect(
      AgentPresentation.tryFromLooseContent('I could not find any records.'),
      isNull,
    );
  });
}
