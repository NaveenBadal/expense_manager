import 'dart:convert';
import 'package:http/http.dart' as http;

class AiClient {
  AiClient({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Uri _uri(String endpoint) {
    final base = endpoint.endsWith('/')
        ? endpoint.substring(0, endpoint.length - 1)
        : endpoint;
    return Uri.parse('$base/api/chat');
  }

  Future<bool> validate({
    required String endpoint,
    required String apiKey,
    required String model,
  }) async {
    try {
      final response = await _client
          .post(
            _uri(endpoint),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': model,
              'stream': false,
              'messages': [
                {'role': 'user', 'content': 'Reply with OK only.'},
              ],
            }),
          )
          .timeout(const Duration(seconds: 20));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<AiReply> answer({
    required String endpoint,
    required String apiKey,
    required String model,
    required String question,
    required String context,
  }) async {
    final response = await _client
        .post(
          _uri(endpoint),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'stream': false,
            'messages': [
              {
                'role': 'system',
                'content':
                    'You are Fund Flow. Use only the supplied locally computed context and never combine currencies. Return only JSON shaped as {"answer":"brief answer","change":null}. If the person explicitly asks to recategorize exactly one listed transaction, change may instead be {"transactionId":123,"category":"New category"}. Never propose any other mutation. Context:\n$context',
              },
              {'role': 'user', 'content': question},
            ],
          }),
        )
        .timeout(const Duration(seconds: 45));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiRequestFailure(response.statusCode);
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final text = (decoded['message'] as Map?)?['content']?.toString().trim();
    if (text == null || text.isEmpty) {
      throw const FormatException('Empty AI answer');
    }
    return AiReply.parse(text);
  }

  void close() => _client.close();
}

class AiReply {
  const AiReply({required this.answer, this.categoryChange});
  final String answer;
  final AiCategoryChange? categoryChange;

  factory AiReply.parse(String text) {
    try {
      final payload = jsonDecode(text) as Map<String, dynamic>;
      final answer = payload['answer']?.toString().trim();
      if (answer == null || answer.isEmpty) throw const FormatException();
      final rawChange = payload['change'];
      AiCategoryChange? change;
      if (rawChange is Map) {
        final id = rawChange['transactionId'];
        final category = rawChange['category']?.toString().trim();
        if (id is num && category != null && category.isNotEmpty) {
          change = AiCategoryChange(id.toInt(), category);
        }
      }
      return AiReply(answer: answer, categoryChange: change);
    } catch (_) {
      return AiReply(answer: text);
    }
  }
}

class AiCategoryChange {
  const AiCategoryChange(this.transactionId, this.category);
  final int transactionId;
  final String category;
}

class AiRequestFailure implements Exception {
  const AiRequestFailure(this.statusCode);
  final int statusCode;
}
