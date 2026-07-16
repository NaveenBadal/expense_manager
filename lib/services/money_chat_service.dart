import 'dart:convert';

import 'package:intl/intl.dart';

import '../models/expense.dart';
import '../models/assistant_message.dart';
import '../models/transaction_query.dart';
import 'local_money_mcp.dart';
import 'ollama_cloud_service.dart';
import '../utils/currency_utils.dart';

typedef ToolApproval =
    Future<bool> Function(String name, Map<String, dynamic> arguments);
typedef AssistantProgress = void Function(String stage);
typedef ToolCompleted = void Function(String name, Map<String, dynamic> result);

class MoneyChatAnswer {
  const MoneyChatAnswer({
    required this.text,
    required this.sources,
    this.checkedRecords = 0,
    this.appliedFilters = const [],
    this.verified = false,
  });

  final String text;
  final List<Expense> sources;
  final int checkedRecords;
  final List<TransactionQuery> appliedFilters;
  final bool verified;
}

/// Ollama-native tool loop backed by an embedded, read-only MCP server.
class MoneyChatService {
  const MoneyChatService(
    this.cloud, {
    this.mcpClient,
    this.approveTool,
    this.onProgress,
    this.onToolCompleted,
  });

  final OllamaCloudService cloud;
  final MoneyMcpClient? mcpClient;
  final ToolApproval? approveTool;
  final AssistantProgress? onProgress;
  final ToolCompleted? onToolCompleted;

  static const _confirmationRequired = {
    'set_app_lock',
    'set_notification_capture',
    'create_transaction',
    'update_transaction',
    'delete_transaction',
    'manage_budget',
    'reanalyze_transaction_sms',
  };

  Future<MoneyChatAnswer> ask(
    String question, {
    List<AssistantMessage> history = const [],
  }) async {
    if (question.trim().isEmpty) {
      throw ArgumentError('Question cannot be empty.');
    }
    final mcp = mcpClient;
    if (mcp == null) throw StateError('The local MCP client is unavailable.');

    onProgress?.call('Discovering secure tools…');
    final mcpTools = await mcp.listTools();
    final allowedNames = mcpTools.map((tool) => tool.name).toSet();
    final ollamaTools = mcpTools
        .map((tool) => tool.toOllamaFunction())
        .toList();
    final now = DateTime.now();
    final messages = <Map<String, dynamic>>[
      {
        'role': 'system',
        'content':
            'You are Flow, the assistant for a private finance app. Local time: '
            '${now.toIso8601String()} (UTC${now.timeZoneOffset}). Use tools for every '
            'transaction fact or app-state action; never invent data or claim a change '
            'unless changed=true. Use search_transactions for lists and '
            'summarize_transactions for totals; call once per comparison period. Resolve '
            'relative dates locally and use full-day start/end times. Set '
            'continue_with_model=true only when results need further AI analysis or another '
            'tool call. Use limit 5 when locating an id to change. Otherwise omit it so the app can '
            'render verified results immediately. For mutations, search first only when the '
            'target id is unknown; confirmation is handled by the host. Re-analyze SMS only '
            'when explicitly requested: find the id, call reanalyze_transaction_sms, infer '
            'only supported source/destination fields, show the proposal, and wait for a later '
            'yes before update_transaction. Never quote raw SMS. Ask one short question only '
            'when essential details are ambiguous. Explain available tools when asked. Refuse '
            'unrelated requests. Be concise, mobile-friendly, and never use tables or SQL.',
      },
      for (final message in history.reversed.take(4).toList().reversed)
        {
          'role': message.user ? 'user' : 'assistant',
          'content': _compactHistory(message.text),
        },
      {'role': 'user', 'content': question},
    ];
    final toolAudit = <Map<String, dynamic>>[];
    final appliedFilters = <TransactionQuery>[];
    final sourceByKey = <String, Expense>{};
    var checkedRecords = 0;
    var reanalyzedSmsThisTurn = false;
    String? draft;

    for (var turn = 0; turn < 4; turn++) {
      onProgress?.call(
        turn == 0 ? 'Understanding your request…' : 'Reviewing tool results…',
      );
      final response = await cloud.chatWithTools(
        messages: messages,
        tools: ollamaTools,
      );
      messages.add(response.assistantMessage);
      if (response.toolCalls.isEmpty) {
        if (response.content.isEmpty) {
          throw const FormatException('The model returned no final answer.');
        }
        draft = response.content;
        break;
      }

      for (final call in response.toolCalls) {
        onProgress?.call('Using ${_friendlyToolName(call.name)}…');
        McpToolResult result;
        if (!allowedNames.contains(call.name)) {
          result = McpToolResult(
            content: 'Unknown tool: ${call.name}',
            structuredContent: const {},
            isError: true,
          );
        } else if (call.name == 'update_transaction' && reanalyzedSmsThisTurn) {
          result = const McpToolResult(
            content:
                'Do not update yet. Present the proposed corrections and ask the user to approve them. Wait for the next user message.',
            structuredContent: {
              'changed': false,
              'awaiting_user_confirmation': true,
            },
            isError: false,
          );
        } else {
          final allowed =
              !_confirmationRequired.contains(call.name) ||
              await (approveTool?.call(call.name, call.arguments) ??
                  Future<bool>.value(false));
          result = allowed
              ? await mcp.callTool(call.name, call.arguments)
              : const McpToolResult(
                  content: 'The user did not approve this sensitive action.',
                  structuredContent: {'changed': false, 'cancelled': true},
                  isError: true,
                );
        }
        final structured = result.structuredContent;
        if (call.name == 'reanalyze_transaction_sms' && !result.isError) {
          reanalyzedSmsThisTurn = true;
        }
        if (!result.isError) onToolCompleted?.call(call.name, structured);
        checkedRecords += (structured['matched_count'] as num?)?.toInt() ?? 0;
        if (structured['applied_filter'] is Map) {
          appliedFilters.add(
            TransactionQuery.fromJson(
              (structured['applied_filter'] as Map).cast<String, dynamic>(),
            ),
          );
        }
        for (final raw in structured['records'] as List<dynamic>? ?? const []) {
          if (raw is! Map) continue;
          final record = _expenseFromTool(raw.cast<String, dynamic>());
          sourceByKey['${record.id}:${record.date.toIso8601String()}'] = record;
        }
        toolAudit.add({
          'tool': call.name,
          'arguments': call.arguments,
          'result': structured,
          'content': result.content,
          'is_error': result.isError,
        });
        messages.add({
          'role': 'tool',
          'tool_name': call.name,
          'content': result.content.isNotEmpty
              ? result.content
              : jsonEncode(structured),
        });
      }
      if (!reanalyzedSmsThisTurn && _canFinishLocally(response.toolCalls)) {
        onProgress?.call('Formatting verified results…');
        return _renderToolAnswer(
          audit: toolAudit,
          sources: sourceByKey.values.toList(),
          checkedRecords: checkedRecords,
          filters: appliedFilters,
        );
      }
    }
    if (draft == null) {
      throw const FormatException('The model exceeded the tool-call limit.');
    }

    return MoneyChatAnswer(
      text: draft,
      sources: sourceByKey.values.toList(),
      checkedRecords: checkedRecords,
      appliedFilters: appliedFilters,
      verified:
          toolAudit.isNotEmpty &&
          toolAudit.every((entry) => entry['is_error'] != true),
    );
  }

  static String _friendlyToolName(String name) => switch (name) {
    'search_transactions' => 'transaction search',
    'summarize_transactions' => 'verified totals',
    'get_app_state' => 'current app settings',
    'set_theme' => 'theme control',
    'set_amount_visibility' => 'privacy control',
    'set_app_lock' => 'app lock control',
    'set_notification_capture' => 'notification capture control',
    'set_currency' => 'currency control',
    'set_sync_lookback' => 'sync memory control',
    'create_transaction' => 'transaction creation',
    'update_transaction' => 'transaction correction',
    'delete_transaction' => 'transaction deletion',
    'manage_budget' => 'budget control',
    'reanalyze_transaction_sms' => 'original SMS re-analysis',
    _ => name.replaceAll('_', ' '),
  };

  static String _compactHistory(String value) {
    const limit = 600;
    final compact = value.trim();
    return compact.length <= limit
        ? compact
        : '${compact.substring(0, limit)}…';
  }

  bool _canFinishLocally(List<OllamaToolCall> calls) {
    if (calls.isEmpty) return false;
    const locallyRendered = {
      'search_transactions',
      'summarize_transactions',
      'set_theme',
      'set_amount_visibility',
      'set_app_lock',
      'set_notification_capture',
      'set_currency',
      'set_sync_lookback',
      'create_transaction',
      'update_transaction',
      'delete_transaction',
      'manage_budget',
    };
    return calls.every(
      (call) =>
          locallyRendered.contains(call.name) &&
          call.arguments['continue_with_model'] != true,
    );
  }

  MoneyChatAnswer _renderToolAnswer({
    required List<Map<String, dynamic>> audit,
    required List<Expense> sources,
    required int checkedRecords,
    required List<TransactionQuery> filters,
  }) {
    final errors = audit.where((entry) => entry['is_error'] == true).toList();
    if (errors.isNotEmpty) {
      final message = errors.first['content']?.toString().trim();
      return MoneyChatAnswer(
        text: message == null || message.isEmpty
            ? 'I could not safely complete that request. Nothing was changed.'
            : message,
        sources: sources,
        checkedRecords: checkedRecords,
        appliedFilters: filters,
      );
    }

    final sections = <String>[];
    for (final entry in audit) {
      final name = entry['tool']?.toString() ?? '';
      final result =
          (entry['result'] as Map?)?.cast<String, dynamic>() ?? const {};
      if (name == 'search_transactions') {
        sections.add(_renderSearch(result));
      } else if (name == 'summarize_transactions') {
        sections.add(_renderSummary(result));
      } else {
        sections.add(_renderAction(name, result));
      }
    }
    return MoneyChatAnswer(
      text: sections.where((value) => value.isNotEmpty).join('\n\n'),
      sources: sources,
      checkedRecords: checkedRecords,
      appliedFilters: filters,
      verified: true,
    );
  }

  String _renderSearch(Map<String, dynamic> result) {
    final count = (result['matched_count'] as num?)?.toInt() ?? 0;
    final records = result['records'] as List<dynamic>? ?? const [];
    if (count == 0) return 'No matching transactions found.';
    final lines = <String>[
      '**$count matching transaction${count == 1 ? '' : 's'}**',
    ];
    for (final raw in records.whereType<Map>()) {
      final item = raw.cast<String, dynamic>();
      final date = DateTime.tryParse(item['date']?.toString() ?? '');
      final amount = (item['amount'] as num?)?.toDouble() ?? 0;
      final currency = item['currency']?.toString() ?? '';
      final merchant = item['merchant']?.toString() ?? 'Unknown';
      final category = item['category']?.toString() ?? 'Others';
      final direction = item['direction'] == 'income' ? 'Received' : 'Paid';
      final when = date == null
          ? ''
          : DateFormat('d MMM · h:mm a').format(date);
      lines.add(
        '- **$merchant** · $direction ${formatAmount(amount, currency)}'
        '${when.isEmpty ? '' : ' · $when'} · $category',
      );
    }
    if (result['records_truncated'] == true) {
      lines.add('_Showing the first ${records.length} of $count matches._');
    }
    return lines.join('\n');
  }

  String _renderSummary(Map<String, dynamic> result) {
    final count = (result['matched_count'] as num?)?.toInt() ?? 0;
    final totals = (result['totals_by_currency'] as Map?) ?? const {};
    if (count == 0) return 'No matching transactions found.';
    final lines = <String>[
      '**$count matching transaction${count == 1 ? '' : 's'}**',
    ];
    for (final entry in totals.entries) {
      final values = (entry.value as Map).cast<String, dynamic>();
      final income = (values['income'] as num?)?.toDouble() ?? 0;
      final expense = (values['expense'] as num?)?.toDouble() ?? 0;
      if (expense > 0) {
        lines.add('- Paid: ${formatAmount(expense, entry.key.toString())}');
      }
      if (income > 0) {
        lines.add('- Received: ${formatAmount(income, entry.key.toString())}');
      }
    }
    return lines.join('\n');
  }

  String _renderAction(String name, Map<String, dynamic> result) {
    if (result['changed'] != true) {
      return result['cancelled'] == true
          ? 'No change was made.'
          : 'The requested change was not applied.';
    }
    return switch (name) {
      'set_theme' =>
        'Theme changed to **${result['theme'] ?? result['mode'] ?? 'the requested mode'}**.',
      'set_amount_visibility' =>
        result['amounts_visible'] == true
            ? 'Amounts are now visible.'
            : 'Amounts are now hidden.',
      'set_app_lock' =>
        result['app_lock_enabled'] == true
            ? 'App lock is enabled.'
            : 'App lock is disabled.',
      'set_notification_capture' =>
        result['notification_capture_enabled'] == true
            ? 'Notification capture is enabled.'
            : 'Notification capture is disabled.',
      'set_currency' =>
        'Preferred currency changed to **${result['preferred_currency']}**.',
      'set_sync_lookback' =>
        'SMS sync will now check the last **${result['sync_lookback_days']} days**.',
      'create_transaction' =>
        'Transaction #${result['transaction_id']} created.',
      'update_transaction' =>
        'Transaction #${result['transaction_id']} updated.',
      'delete_transaction' =>
        'Transaction #${result['transaction_id']} deleted.',
      'manage_budget' =>
        result['removed'] == true
            ? '${result['category']} budget removed.'
            : '${result['category']} budget updated.',
      _ => 'Done.',
    };
  }

  Expense _expenseFromTool(Map<String, dynamic> json) => Expense(
    id: json['id'] as int?,
    amount: (json['amount'] as num).toDouble(),
    currency: json['currency'].toString(),
    merchant: json['merchant'].toString(),
    category: json['category'].toString(),
    date: DateTime.parse(json['date'].toString()),
    originalSms: '',
    type: json['direction'].toString(),
    tags: (json['tags'] as List<dynamic>? ?? const []).join(','),
    isRecurring: json['recurring'] == true,
  );
}
