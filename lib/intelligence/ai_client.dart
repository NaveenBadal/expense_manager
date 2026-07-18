import 'dart:convert';
import '../agent/agent_runner.dart';
import '../agent/mcp_protocol.dart';
import '../domain/transaction.dart';
import '../ingestion/ai_message_ingestion.dart';
import '../ingestion/message_candidate.dart';
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

  AgentProvider configured({
    required String endpoint,
    required String apiKey,
    required String model,
  }) => _ConfiguredAiProvider(
    client: _client,
    uri: _uri(endpoint),
    apiKey: apiKey,
    model: model,
  );

  Future<AiIngestionBatch> analyzeMessages({
    required String endpoint,
    required String apiKey,
    required String model,
    required List<MessageCandidate> candidates,
    required TransactionSource source,
    required DateTime now,
    void Function(String requestJson)? onRequest,
    void Function(String responseJson)? onResponse,
  }) async {
    final requestBody = jsonEncode({
      'model': model,
      'stream': false,
      // Reasoning models (e.g. gpt-oss) otherwise spend tens of seconds and
      // thousands of tokens thinking before a mechanical extraction, and the
      // reasoning trace tempts them off the required schema.
      'think': false,
      'format': IngestionPrompt.responseSchema,
      'messages': [
        {'role': 'system', 'content': IngestionPrompt.system(now)},
        {'role': 'user', 'content': IngestionPrompt.user(candidates)},
      ],
    });
    onRequest?.call(requestBody);
    final response = await _client
        .post(
          _uri(endpoint),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: requestBody,
        )
        .timeout(const Duration(seconds: 60));
    onResponse?.call(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiRequestFailure(response.statusCode);
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final content = (decoded['message'] as Map?)?['content']?.toString();
    if (content == null || content.trim().isEmpty) {
      throw const IngestionSchemaException(
        'The provider returned no classifications.',
      );
    }
    return AiIngestionBatch.parse(
      content: content,
      candidates: candidates,
      source: source,
      now: now,
    );
  }

  void close() => _client.close();
}

class _ConfiguredAiProvider implements AgentProvider {
  const _ConfiguredAiProvider({
    required http.Client client,
    required Uri uri,
    required String apiKey,
    required String model,
  }) : _client = client,
       _uri = uri,
       _apiKey = apiKey,
       _model = model;

  final http.Client _client;
  final Uri _uri;
  final String _apiKey;
  final String _model;

  @override
  Future<ProviderTurn> nextTurn({
    required List<Map<String, Object?>> messages,
    required List<McpToolDefinition> tools,
    void Function(String delta)? onContentDelta,
  }) async {
    final request = http.Request('POST', _uri)
      ..headers.addAll({
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      })
      ..body = jsonEncode({
        'model': _model,
        'stream': true,
        'messages': messages,
        'tools': tools.map((tool) => tool.toProviderJson()).toList(),
      });
    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 45));
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      // Drain so the connection can be released before surfacing the error.
      await streamed.stream.drain<void>();
      throw AiRequestFailure(streamed.statusCode);
    }

    final contentBuffer = StringBuffer();
    final rawCalls = <Map<Object?, Object?>>[];
    Object? role;
    var carry = '';

    void handleLine(String line) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) return;
      final Object? decoded;
      try {
        decoded = jsonDecode(trimmed);
      } on FormatException {
        // Ignore keep-alive or non-JSON framing lines.
        return;
      }
      if (decoded is! Map) return;
      final rawMessage = decoded['message'];
      if (rawMessage is Map) {
        role ??= rawMessage['role'];
        final delta = rawMessage['content'];
        if (delta is String && delta.isNotEmpty) {
          contentBuffer.write(delta);
          onContentDelta?.call(delta);
        }
        final calls = rawMessage['tool_calls'];
        if (calls is List) {
          for (final call in calls) {
            if (call is Map) rawCalls.add(Map<Object?, Object?>.from(call));
          }
        }
      }
    }

    await for (final chunk
        in streamed.stream.transform(utf8.decoder).timeout(
          const Duration(seconds: 45),
        )) {
      carry += chunk;
      var newline = carry.indexOf('\n');
      while (newline != -1) {
        handleLine(carry.substring(0, newline));
        carry = carry.substring(newline + 1);
        newline = carry.indexOf('\n');
      }
    }
    if (carry.trim().isNotEmpty) handleLine(carry);

    final content = contentBuffer.toString();
    final message = <String, Object?>{
      'role': role?.toString() ?? 'assistant',
      'content': content,
      if (rawCalls.isNotEmpty) 'tool_calls': rawCalls,
    };
    final calls = <McpToolCall>[];
    for (var index = 0; index < rawCalls.length; index++) {
      calls.add(McpToolCall.fromProviderJson(rawCalls[index], index));
    }
    return ProviderTurn(
      message: message,
      content: content,
      toolCalls: calls,
    );
  }
}

class AiRequestFailure implements Exception {
  const AiRequestFailure(this.statusCode);
  final int statusCode;
}
