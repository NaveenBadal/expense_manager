import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';

import 'message_candidate.dart';

enum MessagePermission { undecided, granted, denied, permanentlyDenied }

typedef SmsPageReader =
    Future<List<MessageCandidate>> Function(
      DateTime after,
      int start,
      int count,
    );

class SmsSource {
  SmsSource({SmsQuery? query, SmsPageReader? pageReader, bool? useNativePaging})
    : _query = query ?? SmsQuery(),
      _pageReader = pageReader,
      _useNativePaging = useNativePaging ?? (!kIsWeb && Platform.isAndroid);

  static const _pageSize = 500;
  static const _channel = MethodChannel('fund_flow/sms_history');

  final SmsQuery _query;
  final SmsPageReader? _pageReader;
  final bool _useNativePaging;

  Future<MessagePermission> permission({bool request = false}) async {
    var status = await Permission.sms.status;
    if (request && !status.isGranted) status = await Permission.sms.request();
    if (status.isGranted) return MessagePermission.granted;
    if (status.isPermanentlyDenied) return MessagePermission.permanentlyDenied;
    if (status.isDenied) return MessagePermission.denied;
    return MessagePermission.undecided;
  }

  Future<List<MessageCandidate>> recent(int days) async {
    final after = DateTime.now().subtract(Duration(days: days));
    final values = <MessageCandidate>[];
    final seen = <String>{};
    for (var start = 0; ; start += _pageSize) {
      final page =
          await (_pageReader?.call(after, start, _pageSize) ??
              _readPage(after, start, _pageSize));
      if (page.isEmpty) break;
      var added = 0;
      for (final candidate in page) {
        if (!candidate.receivedAt.isAfter(after)) continue;
        if (seen.add(candidate.fingerprint)) {
          values.add(candidate);
          added++;
        }
      }
      if (page.length < _pageSize || added == 0) break;
    }
    values.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    return values;
  }

  Future<List<MessageCandidate>> _readPage(
    DateTime after,
    int start,
    int count,
  ) async {
    if (_useNativePaging) {
      final raw =
          await _channel.invokeListMethod<Object?>('queryPage', {
            'after': after.millisecondsSinceEpoch,
            'start': start,
            'count': count,
          }) ??
          const [];
      return [
        for (final item in raw)
          if (item is Map)
            MessageCandidate(
              body: item['body']?.toString() ?? '',
              receivedAt: DateTime.fromMillisecondsSinceEpoch(
                (item['date'] as num?)?.toInt() ?? 0,
              ),
              sender: item['address']?.toString(),
            ),
      ];
    }

    final messages = await _query.querySms(
      kinds: [SmsQueryKind.inbox],
      sort: true,
      start: start,
      count: count,
    );
    return [
      for (final message in messages)
        MessageCandidate(
          body: message.body ?? '',
          receivedAt: message.date ?? DateTime.fromMillisecondsSinceEpoch(0),
          sender: message.sender,
        ),
    ];
  }
}
