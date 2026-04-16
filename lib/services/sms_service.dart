import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';

class SmsService {
  final SmsQuery _query = SmsQuery();

  Future<bool> requestPermissions() async {
    var status = await Permission.sms.status;
    if (status.isDenied) {
      status = await Permission.sms.request();
    }
    return status.isGranted;
  }

  Future<List<SmsMessage>> getMessages() async {
    return await _query.querySms(
      kinds: [SmsQueryKind.inbox],
    );
  }

  // All messages in the lookback period will be sent to AI for validation.
  bool isFinancialSms(String body) {
    return true; 
  }
}
