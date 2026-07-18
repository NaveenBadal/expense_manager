import 'package:flutter/services.dart';

import 'message_candidate.dart';

class NotificationSource {
  const NotificationSource();
  static const _channel = MethodChannel('fund_flow/notification_source');

  Future<bool> hasAccess() async =>
      await _channel.invokeMethod<bool>('isAccessEnabled') ?? false;

  Future<void> openAccessSettings() =>
      _channel.invokeMethod<void>('openAccessSettings');

  Future<void> setEnabled(bool value) =>
      _channel.invokeMethod<void>('setCaptureEnabled', {'enabled': value});

  Future<List<NotificationCandidate>> pending() async {
    final rows = await _channel.invokeListMethod<Object?>('getPending') ?? [];
    return rows.map((row) {
      final value = Map<Object?, Object?>.from(row! as Map);
      return NotificationCandidate(
        id: value['id']?.toString() ?? '',
        candidate: MessageCandidate(
          body: value['body']?.toString() ?? '',
          sender: value['title']?.toString(),
          receivedAt: DateTime.fromMillisecondsSinceEpoch(
            (value['postedAt'] as num?)?.toInt() ?? 0,
          ),
        ),
      );
    }).toList();
  }

  Future<void> acknowledge(Iterable<String> ids) =>
      _channel.invokeMethod<void>('acknowledge', {'ids': ids.toList()});
}

class NotificationCandidate {
  const NotificationCandidate({required this.id, required this.candidate});
  final String id;
  final MessageCandidate candidate;
}
