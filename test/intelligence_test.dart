import 'package:expense_manager/intelligence/ai_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI reply exposes only the constrained category proposal', () {
    final reply = AiReply.parse(
      '{"answer":"I found it.","change":{"transactionId":42,"category":"Travel"}}',
    );
    expect(reply.answer, 'I found it.');
    expect(reply.categoryChange?.transactionId, 42);
    expect(reply.categoryChange?.category, 'Travel');
  });

  test('plain provider text remains a read-only answer', () {
    final reply = AiReply.parse('There is not enough activity yet.');
    expect(reply.answer, 'There is not enough activity yet.');
    expect(reply.categoryChange, isNull);
  });
}
