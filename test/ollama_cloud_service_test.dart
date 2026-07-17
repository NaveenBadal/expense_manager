import 'dart:convert';

import 'package:expense_manager/services/money_chat_service.dart';
import 'package:expense_manager/services/local_money_mcp.dart';
import 'package:expense_manager/services/ollama_cloud_service.dart';
import 'package:expense_manager/services/database_helper.dart';
import 'package:expense_manager/widgets/money_chat_sheet.dart';
import 'package:expense_manager/models/assistant_message.dart';
import 'package:expense_manager/models/agent_artifact.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('assistant messages round-trip through their persisted shape', () {
    final original = AssistantMessage(
      id: 4,
      user: false,
      text: 'Verified answer',
      sources: 3,
      verified: true,
      timestamp: DateTime(2026, 7, 16, 10, 30),
    );
    final restored = AssistantMessage.fromMap(original.toMap());

    expect(restored.id, 4);
    expect(restored.text, 'Verified answer');
    expect(restored.sources, 3);
    expect(restored.verified, isTrue);
    expect(restored.timestamp, original.timestamp);
  });

  test('chat converts markdown tables into mobile-friendly rows', () {
    final result = mobileFriendlyMarkdown(
      '| Date | Amount |\n| --- | --- |\n| 20 Jun | ₹450 |',
    );

    expect(result, contains('**Date:** 20 Jun'));
    expect(result, contains('**Amount:** ₹450'));
    expect(result, isNot(contains('| --- |')));
  });

  test('local money server negotiates MCP and lists typed tools', () async {
    String? appCall;
    final server = LocalMoneyMcpServer(
      DatabaseHelper.instance,
      appToolHandler: (name, arguments) async {
        appCall = name;
        return {'changed': true, ...arguments};
      },
    );
    final initialized = await server.handle({
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'initialize',
      'params': {
        'protocolVersion': '2025-11-25',
        'capabilities': {},
        'clientInfo': {'name': 'test', 'version': '1'},
      },
    });
    final listed = await server.handle({
      'jsonrpc': '2.0',
      'id': 2,
      'method': 'tools/list',
      'params': {},
    });

    expect((initialized?['result'] as Map)['protocolVersion'], '2025-11-25');
    final tools = ((listed?['result'] as Map)['tools'] as List)
        .cast<Map<String, dynamic>>();
    expect(
      tools.map((tool) => tool['name']),
      containsAll([
        'search_transactions',
        'summarize_transactions',
        'reanalyze_transaction_sms',
        'set_theme',
        'set_amount_visibility',
      ]),
    );
    expect(tools.first['inputSchema'], isA<Map<String, dynamic>>());
    expect(tools.first['outputSchema'], isA<Map<String, dynamic>>());
    final changed = await server.handle({
      'jsonrpc': '2.0',
      'id': 3,
      'method': 'tools/call',
      'params': {
        'name': 'set_theme',
        'arguments': {'mode': 'dark'},
      },
    });
    expect(appCall, 'set_theme');
    expect(
      ((changed?['result'] as Map)['structuredContent'] as Map)['changed'],
      isTrue,
    );
  });

  test('parses an out-of-order AI batch using stable ids', () async {
    late Map<String, dynamic> requestBody;
    final client = MockClient((request) async {
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'message': {
            'content': jsonEncode({
              'results': [
                {
                  'id': 1,
                  'type': 'not_financial',
                  'amount': null,
                  'merchant': null,
                  'category': null,
                },
                {
                  'id': 0,
                  'type': 'expense',
                  'amount': '1,249.50',
                  'merchant': 'SWIGGY',
                  'category': 'food',
                },
              ],
            }),
          },
        }),
        200,
      );
    });

    final service = OllamaCloudService(
      apiKey: 'test',
      model: 'gpt-oss:20b-cloud',
      client: client,
    );
    final results = await service.parseBatch(['debit sms', 'otp sms']);

    expect(results[0]?.amount, 1249.5);
    expect(results[0]?.category, 'Food');
    expect(results[1]?.type, 'not_financial');
    expect(requestBody['think'], 'medium');
    expect(requestBody['stream'], false);
    final systemPrompt =
        ((requestBody['messages'] as List).first as Map)['content'].toString();
    expect(systemPrompt, contains('WHERE THE MONEY WENT'));
    expect(systemPrompt, contains('WHERE THE MONEY CAME FROM'));
    expect(systemPrompt, contains('does not mean only a retail shop'));
  });

  test('rejects batches above the optimized maximum', () async {
    final service = OllamaCloudService(
      apiKey: 'test',
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    expect(
      () => service.parseBatch(List.filled(13, 'sms')),
      throwsArgumentError,
    );
  });

  test('streaming chat retries transient service failures', () async {
    var attempts = 0;
    final service = OllamaCloudService(
      apiKey: 'test',
      client: MockClient((_) async {
        attempts++;
        if (attempts < 3) return http.Response('busy', 503);
        return http.Response(
          jsonEncode({
            'message': {'role': 'assistant', 'content': 'Ready'},
          }),
          200,
        );
      }),
    );

    final turn = await service.chatWithTools(
      messages: const [
        {'role': 'user', 'content': 'Hello'},
      ],
      tools: const [],
    );

    expect(attempts, 3);
    expect(turn.content, 'Ready');
  });

  test(
    'money chat uses role context instead of a manual prompt gate',
    () async {
      var requests = 0;
      final mcp = _FakeMoneyMcpClient();
      final service = MoneyChatService(
        OllamaCloudService(
          apiKey: 'test',
          client: MockClient((_) async {
            requests++;
            const content =
                'I can only help with Flow and your personal finances.';
            return http.Response(
              jsonEncode({
                'message': {'role': 'assistant', 'content': content},
              }),
              200,
            );
          }),
        ),
        mcpClient: mcp,
      );

      final answer = await service.ask('Create a Python game for me');

      expect(answer.text, contains('personal finances'));
      expect(answer.sources, isEmpty);
      expect(requests, 1);
      expect(mcp.calledTools, isEmpty);
    },
  );

  test('money chat keeps ten bounded turns for durable context', () async {
    late Map<String, dynamic> requestBody;
    final service = MoneyChatService(
      OllamaCloudService(
        apiKey: 'test',
        client: MockClient((request) async {
          requestBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'message': {
                'role': 'assistant',
                'content': 'I can help with Flow.',
              },
            }),
            200,
          );
        }),
      ),
      mcpClient: _FakeMoneyMcpClient(),
    );
    final history = List.generate(
      10,
      (index) => AssistantMessage(
        user: index.isEven,
        text: 'message $index ${'x' * 1000}',
        timestamp: DateTime(2026, 7, 16),
      ),
    );

    await service.ask('What can you do?', history: history);

    final messages = requestBody['messages'] as List<dynamic>;
    expect(messages, hasLength(12));
    for (final message in messages.skip(1).take(10).cast<Map>()) {
      expect(message['content'].toString().length, lessThanOrEqualTo(601));
    }
  });

  test('money chat renders MCP records in one model request', () async {
    final requests = <Map<String, dynamic>>[];
    var call = 0;
    final mcp = _FakeMoneyMcpClient();
    final service = MoneyChatService(
      OllamaCloudService(
        apiKey: 'test',
        client: MockClient((request) async {
          requests.add(jsonDecode(request.body) as Map<String, dynamic>);
          call++;
          final message = {
            'role': 'assistant',
            'content': '',
            'tool_calls': [
              {
                'type': 'function',
                'function': {
                  'name': 'search_transactions',
                  'arguments': {
                    'label': 'primary',
                    'from': '2026-06-20T00:00:00+05:30',
                    'to': '2026-06-20T23:59:59.999999+05:30',
                    'limit': 50,
                  },
                },
              },
            ],
          };
          return http.Response(jsonEncode({'message': message}), 200);
        }),
      ),
      mcpClient: mcp,
    );

    final answer = await service.ask(
      'What about that date?',
      history: [
        AssistantMessage(
          user: true,
          text: 'Get my transactions from 20 June',
          timestamp: DateTime(2026, 7, 16),
        ),
      ],
    );

    expect(call, 1);
    expect(mcp.calledTools, ['search_transactions']);
    expect(answer.verified, isTrue);
    expect(answer.checkedRecords, 1);
    expect(answer.sources.single.id, 7);
    expect(answer.appliedFilters.single.from?.day, 20);
    expect(answer.text, contains('Cafe'));
    expect(answer.text, contains('₹450.00'));
    expect(requests.first['tools'], isNotEmpty);
    final firstMessages = requests.first['messages'] as List;
    expect(
      firstMessages.any(
        (message) => message['content'] == 'Get my transactions from 20 June',
      ),
      isTrue,
    );
    expect(requests.single['think'], 'low');
    expect(requests.single['keep_alive'], '10m');
    expect(requests.single['stream'], isTrue);
  });

  test(
    'main chat changes settings only through a successful app tool',
    () async {
      var call = 0;
      final mcp = _FakeMoneyMcpClient();
      final service = MoneyChatService(
        OllamaCloudService(
          apiKey: 'test',
          client: MockClient((_) async {
            call++;
            final message = {
              'role': 'assistant',
              'content': '',
              'tool_calls': [
                {
                  'type': 'function',
                  'function': {
                    'name': 'set_theme',
                    'arguments': {'mode': 'dark'},
                  },
                },
              ],
            };
            return http.Response(jsonEncode({'message': message}), 200);
          }),
        ),
        mcpClient: mcp,
      );

      final answer = await service.ask('Make this easier on my eyes at night');

      expect(mcp.calledTools, ['set_theme']);
      expect(answer.text, contains('dark'));
      expect(answer.verified, isTrue);
      expect(call, 1);
    },
  );

  test('SMS re-analysis must wait for a later user approval turn', () async {
    var call = 0;
    final mcp = _FakeMoneyMcpClient();
    final service = MoneyChatService(
      OllamaCloudService(
        apiKey: 'test',
        client: MockClient((_) async {
          call++;
          final message = switch (call) {
            1 => {
              'role': 'assistant',
              'content': '',
              'tool_calls': [
                {
                  'type': 'function',
                  'function': {
                    'name': 'reanalyze_transaction_sms',
                    'arguments': {'id': 7},
                  },
                },
              ],
            },
            2 => {
              'role': 'assistant',
              'content': '',
              'tool_calls': [
                {
                  'type': 'function',
                  'function': {
                    'name': 'update_transaction',
                    'arguments': {'id': 7, 'merchant': 'Blue Tokai'},
                  },
                },
              ],
            },
            3 => {
              'role': 'assistant',
              'content':
                  'I found Blue Tokai instead of Unknown. Would you like me to update it?',
            },
            _ => {
              'role': 'assistant',
              'content': jsonEncode({
                'valid': true,
                'answer':
                    'I found Blue Tokai instead of Unknown. Would you like me to update it?',
              }),
            },
          };
          return http.Response(jsonEncode({'message': message}), 200);
        }),
      ),
      mcpClient: mcp,
      approveTool: (_, _) async => true,
    );

    final answer = await service.ask('Re-analyze transaction 7 SMS');

    expect(mcp.calledTools, ['reanalyze_transaction_sms']);
    expect(answer.text, contains('Would you like me to update it?'));
  });

  test('agent renders a verified typed spending artifact', () async {
    final service = MoneyChatService(
      OllamaCloudService(
        apiKey: 'test',
        client: MockClient((_) async {
          return http.Response(
            jsonEncode({
              'message': {
                'role': 'assistant',
                'content': '',
                'tool_calls': [
                  {
                    'type': 'function',
                    'function': {
                      'name': 'spending_breakdown',
                      'arguments': {'group_by': 'category'},
                    },
                  },
                ],
              },
            }),
            200,
          );
        }),
      ),
      mcpClient: _FakeMoneyMcpClient(),
    );

    final answer = await service.ask('Where did my money go?');

    expect(answer.verified, isTrue);
    expect(answer.artifact.kind, AgentArtifactKind.breakdown);
    expect(answer.artifact.data['groups'], isNotEmpty);
  });

  test('agent cancellation stops before a cloud request', () async {
    var requested = false;
    final token = AgentCancellationToken()..cancel();
    final service = MoneyChatService(
      OllamaCloudService(
        apiKey: 'test',
        client: MockClient((_) async {
          requested = true;
          return http.Response('{}', 200);
        }),
      ),
      mcpClient: _FakeMoneyMcpClient(),
      cancellationToken: token,
    );

    await expectLater(
      service.ask('Summarize today'),
      throwsA(isA<AgentCancelledException>()),
    );
    expect(requested, isFalse);
  });
}

class _FakeMoneyMcpClient implements MoneyMcpClient {
  final calledTools = <String>[];

  @override
  Future<List<McpToolDefinition>> listTools() async => [
    const McpToolDefinition(
      name: 'search_transactions',
      description: 'Search matching local transactions.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'from': {
            'type': ['string', 'null'],
          },
          'to': {
            'type': ['string', 'null'],
          },
          'limit': {'type': 'integer'},
        },
      },
    ),
    const McpToolDefinition(
      name: 'set_theme',
      description: 'Actually change the app theme.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'mode': {
            'type': 'string',
            'enum': ['system', 'light', 'dark'],
          },
        },
        'required': ['mode'],
      },
    ),
    const McpToolDefinition(
      name: 'reanalyze_transaction_sms',
      description: 'Re-analyze one original SMS after consent.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': {'type': 'integer'},
        },
        'required': ['id'],
      },
    ),
    const McpToolDefinition(
      name: 'update_transaction',
      description: 'Update a transaction after approval.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': {'type': 'integer'},
          'merchant': {'type': 'string'},
        },
        'required': ['id'],
      },
    ),
    const McpToolDefinition(
      name: 'spending_breakdown',
      description: 'Calculate a grouped spending breakdown.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'group_by': {'type': 'string'},
        },
        'required': ['group_by'],
      },
    ),
  ];

  @override
  Future<McpToolResult> callTool(
    String name,
    Map<String, dynamic> arguments,
  ) async {
    calledTools.add(name);
    if (name == 'reanalyze_transaction_sms') {
      final result = {
        'transaction_id': arguments['id'],
        'current_merchant': 'Unknown',
        'original_sms': 'Paid INR 450 at BLUE TOKAI',
      };
      return McpToolResult(
        content: jsonEncode(result),
        structuredContent: result,
        isError: false,
      );
    }
    if (name == 'set_theme') {
      final result = {'changed': true, 'theme': arguments['mode']};
      return McpToolResult(
        content: jsonEncode(result),
        structuredContent: result,
        isError: false,
      );
    }
    if (name == 'spending_breakdown') {
      final result = {
        'applied_filter': arguments,
        'group_by': 'category',
        'matched_count': 2,
        'groups': [
          {
            'label': 'Food',
            'currency': 'INR',
            'direction': 'expense',
            'count': 2,
            'total': 700,
          },
        ],
      };
      return McpToolResult(
        content: jsonEncode(result),
        structuredContent: result,
        isError: false,
      );
    }
    final result = {
      'applied_filter': arguments,
      'matched_count': 1,
      'totals_by_currency': {
        'INR': {'income': 0, 'expense': 450},
      },
      'records_truncated': false,
      'records': [
        {
          'id': 7,
          'date': '2026-06-20T12:30:00.000',
          'amount': 450,
          'currency': 'INR',
          'direction': 'expense',
          'merchant': 'Cafe',
          'category': 'Food',
          'tags': <String>[],
          'recurring': false,
        },
      ],
    };
    return McpToolResult(
      content: jsonEncode(result),
      structuredContent: result,
      isError: false,
    );
  }
}
