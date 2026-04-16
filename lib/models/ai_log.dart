class AiLog {
  final int? id;
  final String requestPrompt;
  final String responseBody;
  final DateTime timestamp;
  final String status;

  AiLog({
    this.id,
    required this.requestPrompt,
    required this.responseBody,
    required this.timestamp,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'requestPrompt': requestPrompt,
      'responseBody': responseBody,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
    };
  }

  factory AiLog.fromMap(Map<String, dynamic> map) {
    return AiLog(
      id: map['id'],
      requestPrompt: map['requestPrompt'],
      responseBody: map['responseBody'],
      timestamp: DateTime.parse(map['timestamp']),
      status: map['status'],
    );
  }
}
