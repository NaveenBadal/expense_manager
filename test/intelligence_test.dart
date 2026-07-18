import 'dart:convert';

import 'package:fund_flow/agent/mcp_protocol.dart';
import 'package:fund_flow/intelligence/ai_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('provider adapter sends tools and decodes native tool calls', () async {
    late Map<String, dynamic> requestBody;
    final client = AiClient(
      client: MockClient((request) async {
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'message': {
              'role': 'assistant',
              'content': '',
              'tool_calls': [
                {
                  'id': 'call_1',
                  'function': {
                    'name': 'settings_get',
                    'arguments': <String, Object?>{},
                  },
                },
              ],
            },
          }),
          200,
        );
      }),
    );
    addTearDown(client.close);
    final provider = client.configured(
      endpoint: 'https://provider.example',
      apiKey: 'secret',
      model: 'agent-model',
    );
    final turn = await provider.nextTurn(
      messages: const [
        {'role': 'user', 'content': 'What are my settings?'},
      ],
      tools: const [
        McpToolDefinition(
          name: 'settings_get',
          description: 'Read settings',
          inputSchema: {
            'type': 'object',
            'properties': <String, Object?>{},
            'additionalProperties': false,
          },
          risk: McpRisk.read,
        ),
      ],
    );
    expect(requestBody['model'], 'agent-model');
    expect(requestBody['tools'], hasLength(1));
    expect(turn.toolCalls.single.name, 'settings_get');
    expect(turn.toolCalls.single.arguments, isEmpty);
  });
}
