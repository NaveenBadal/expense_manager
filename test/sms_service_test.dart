import 'package:expense_manager/services/sms_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/sms_history');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'requests the complete Android inbox range using the selected cutoff',
    () async {
      final cutoff = DateTime(2026, 1, 14);
      MethodCall? capturedCall;
      final rows = List.generate(250, (index) {
        return {
          '_id': index,
          'address': 'BANK',
          'body': 'Transaction $index',
          'date': cutoff.millisecondsSinceEpoch + index,
        };
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            capturedCall = call;
            return rows;
          });

      final messages = await SmsService(
        historyChannel: channel,
        isAndroid: true,
      ).getMessages(since: cutoff);

      expect(capturedCall?.method, 'querySince');
      expect(
        (capturedCall?.arguments as Map)['since'],
        cutoff.millisecondsSinceEpoch,
      );
      expect(messages, hasLength(250));
      expect(messages.last.body, 'Transaction 249');
    },
  );
}
