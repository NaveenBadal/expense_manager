import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';

class SmsService {
  SmsService({MethodChannel? historyChannel, bool? isAndroid})
    : _historyChannel = historyChannel ?? _defaultHistoryChannel,
      _isAndroid = isAndroid ?? (!kIsWeb && Platform.isAndroid);

  static const _defaultHistoryChannel = MethodChannel(
    'com.naveen.expense_manager/sms_history',
  );

  final SmsQuery _query = SmsQuery();
  final MethodChannel _historyChannel;
  final bool _isAndroid;

  Future<bool> requestPermissions() async {
    var status = await Permission.sms.status;
    if (status.isDenied) {
      status = await Permission.sms.request();
    }
    return status.isGranted;
  }

  Future<List<SmsMessage>> getMessages({required DateTime since}) async {
    if (_isAndroid) {
      final raw =
          await _historyChannel.invokeListMethod<dynamic>('querySince', {
            'since': since.millisecondsSinceEpoch,
          }) ??
          const [];
      return [
        for (final item in raw)
          if (item is Map) SmsMessage.fromJson(item),
      ];
    }

    // READ_SMS is Android-only. Keep a bounded fallback for tests and any
    // unsupported platform instead of silently using the plugin's 200-message
    // default page.
    return _query.querySms(count: 1000, kinds: [SmsQueryKind.inbox]);
  }

  // Filters for messages that look like financial transactions (debit, credit, spent, etc.)
  bool isFinancialSms(String body) {
    final lowerBody = body.toLowerCase();

    // OTPs should be excluded first for security
    if (lowerBody.contains('otp') || lowerBody.contains('verification code')) {
      return false;
    }

    // Key terms indicating a transaction.
    // We include currency symbols, abbreviations, and short forms used by Indian banks.
    final financialKeywords = [
      'spent', 'debited', 'credited', 'debit', 'credit', 'paid', 'txn',
      'purchase', 'vpa', 'upi', 'bank', 'amt', 'amount',
      r'rs\.',
      'inr',
      'rs ',
      '₹',
      r'\$',
      '€',
      'withdrawn',
      'deducted',
      'avail bal',
      'refunded',
      'reversed',
      'collected',
      'payment',
      'bill',
      'due',
      'money transfer',
      // Short forms heavily used by HDFC, SBI, ICICI, Axis
      ' dr ', ' cr ', r'dr\.', r'cr\.', 'dr-', 'cr-',
      // Transfer/wallet keywords
      'transferred', 'received', 'imps', 'neft', 'rtgs', 'mandate',
      'a/c', 'acct', 'account', 'wallet', 'cashback',
    ];

    // We use a more relaxed regex that doesn't strictly require word boundaries
    // for symbols like ₹ or $.
    final pattern = RegExp(
      '(${financialKeywords.join('|')})',
      caseSensitive: false,
    );

    return pattern.hasMatch(lowerBody);
  }
}
