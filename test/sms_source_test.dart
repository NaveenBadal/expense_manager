import 'package:flutter_test/flutter_test.dart';
import 'package:fund_flow/ingestion/message_candidate.dart';
import 'package:fund_flow/ingestion/sms_source.dart';

void main() {
  test('reads every SMS page without a 500-message ceiling', () async {
    final now = DateTime.now();
    final messages = List.generate(
      1205,
      (index) => MessageCandidate(
        body: 'Opaque message $index',
        receivedAt: now.subtract(Duration(minutes: index)),
        sender: 'sender-$index',
      ),
    );
    final starts = <int>[];
    final source = SmsSource(
      useNativePaging: false,
      pageReader: (_, start, count) async {
        starts.add(start);
        return messages.skip(start).take(count).toList();
      },
    );

    final result = await source.recent(30);

    expect(result, hasLength(1205));
    expect(starts, [0, 500, 1000]);
  });

  test('stops safely when a source repeats the same full page', () async {
    final now = DateTime.now();
    final page = List.generate(
      500,
      (index) => MessageCandidate(
        body: 'Opaque message $index',
        receivedAt: now.subtract(Duration(minutes: index)),
        sender: 'sender-$index',
      ),
    );
    var calls = 0;
    final source = SmsSource(
      useNativePaging: false,
      pageReader: (_, _, _) async {
        calls++;
        return page;
      },
    );

    final result = await source.recent(30);

    expect(result, hasLength(500));
    expect(calls, 2);
  });
}
