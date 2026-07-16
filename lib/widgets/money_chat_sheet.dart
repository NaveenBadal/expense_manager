import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/expense_provider.dart';
import '../providers/notification_ingestion_provider.dart';
import '../services/local_money_mcp.dart';
import '../services/money_chat_service.dart';
import '../services/ollama_cloud_service.dart';

class MoneyChatSheet extends ConsumerStatefulWidget {
  const MoneyChatSheet({super.key, this.initialPrompt});
  final String? initialPrompt;
  @override
  ConsumerState<MoneyChatSheet> createState() => _MoneyChatSheetState();
}

class _MoneyChatSheetState extends ConsumerState<MoneyChatSheet> {
  final _controller = TextEditingController();
  final _messages = <({bool user, String text, int sources, bool verified})>[];
  bool _thinking = false;

  static const _prompts = [
    'What changed in my spending this month?',
    'Where can I safely spend less?',
    'Find subscriptions I may have forgotten',
  ];

  @override
  void initState() {
    super.initState();
    final prompt = widget.initialPrompt?.trim();
    if (prompt != null && prompt.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ask(prompt));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ask([String? suggested]) async {
    final question = (suggested ?? _controller.text).trim();
    if (question.isEmpty || _thinking) return;
    _controller.clear();
    setState(() {
      _messages.add((user: true, text: question, sources: 0, verified: false));
      _thinking = true;
    });
    try {
      final service = MoneyChatService(
        OllamaCloudService(
          apiKey: ref.read(ollamaApiKeyProvider),
          baseUrl: ref.read(ollamaBaseUrlProvider),
          model: ref.read(ollamaModelProvider),
        ),
        mcpClient: LocalMoneyMcpClient(
          LocalMoneyMcpServer(
            ref.read(databaseProvider),
            appToolHandler: _handleAppTool,
          ),
        ),
      );
      final answer = await service.ask(question);
      if (!mounted) return;
      setState(
        () => _messages.add((
          user: false,
          text: answer.text,
          sources: answer.checkedRecords,
          verified: answer.verified,
        )),
      );
    } catch (error) {
      if (!mounted) return;
      final missingKey = ref.read(ollamaApiKeyProvider).trim().isEmpty;
      setState(
        () => _messages.add((
          user: false,
          text: missingKey
              ? 'Connect your AI model in Settings, then I can reason over your money.'
              : 'I could not complete that analysis. Your transaction data was not changed.',
          sources: 0,
          verified: false,
        )),
      );
    } finally {
      if (mounted) setState(() => _thinking = false);
    }
  }

  Future<Map<String, dynamic>> _handleAppTool(
    String name,
    Map<String, dynamic> arguments,
  ) async {
    switch (name) {
      case 'get_app_state':
        return {
          'theme': ref.read(themeModeProvider).name,
          'amounts_visible': !ref.read(privateModeProvider),
          'app_lock_enabled': ref.read(appLockEnabledProvider),
          'notification_capture_enabled': ref.read(
            notificationParsingEnabledProvider,
          ),
          'preferred_currency': ref.read(preferredCurrencyProvider),
          'sync_lookback_days': ref.read(syncLookbackProvider),
        };
      case 'set_theme':
        final value = arguments['mode']?.toString();
        final mode = switch (value) {
          'dark' => ThemeMode.dark,
          'light' => ThemeMode.light,
          'system' => ThemeMode.system,
          _ => throw ArgumentError('mode must be system, light, or dark'),
        };
        ref.read(themeModeProvider.notifier).setThemeMode(mode);
        await ref
            .read(secureStorageProvider)
            .write(key: 'theme_mode', value: mode.toString());
        return {'changed': true, 'theme': mode.name};
      case 'set_amount_visibility':
        final visible = arguments['visible'];
        if (visible is! bool) throw ArgumentError('visible must be boolean');
        await ref.read(privateModeProvider.notifier).set(!visible);
        return {'changed': true, 'amounts_visible': visible};
      case 'set_app_lock':
        final enabled = arguments['enabled'];
        if (enabled is! bool) throw ArgumentError('enabled must be boolean');
        await ref.read(appLockEnabledProvider.notifier).setEnabled(enabled);
        return {'changed': true, 'app_lock_enabled': enabled};
      case 'set_notification_capture':
        final enabled = arguments['enabled'];
        if (enabled is! bool) throw ArgumentError('enabled must be boolean');
        await ref
            .read(notificationIngestionProvider.notifier)
            .setEnabled(enabled);
        return {'changed': true, 'notification_capture_enabled': enabled};
      case 'set_currency':
        final currency = arguments['currency']?.toString().toUpperCase();
        const allowed = {'INR', 'USD', 'EUR', 'GBP', 'SGD', 'AED'};
        if (!allowed.contains(currency)) {
          throw ArgumentError('unsupported currency');
        }
        await ref
            .read(preferredCurrencyProvider.notifier)
            .setCurrency(currency!);
        return {'changed': true, 'preferred_currency': currency};
      case 'set_sync_lookback':
        final days = (arguments['days'] as num?)?.toInt();
        if (days == null || days < 7 || days > 180) {
          throw ArgumentError('days must be between 7 and 180');
        }
        ref.read(syncLookbackProvider.notifier).setDays(days);
        await ref
            .read(secureStorageProvider)
            .write(key: 'sync_lookback_days', value: '$days');
        return {'changed': true, 'sync_lookback_days': days};
      default:
        throw ArgumentError('unknown app tool');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      height: MediaQuery.sizeOf(context).height * .88,
      padding: EdgeInsets.fromLTRB(20, 14, 20, 16 + bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF090D16),
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.blur_circular_rounded, color: Color(0xFFC7FF4A)),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ask Flow',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Your transactions and app controls, in one place',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: _messages.isEmpty
                ? ListView(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: Text(
                          'I can calculate, compare, trace patterns, and explain.\nWhat do you want to know?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            height: 1.2,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      for (final prompt in _prompts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: OutlinedButton(
                            onPressed: () => _ask(prompt),
                            style: OutlinedButton.styleFrom(
                              alignment: Alignment.centerLeft,
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Colors.white12),
                              padding: const EdgeInsets.all(17),
                            ),
                            child: Text(prompt),
                          ),
                        ),
                    ],
                  )
                : ListView.builder(
                    itemCount: _messages.length + (_thinking ? 1 : 0),
                    itemBuilder: (_, index) {
                      if (index == _messages.length) {
                        return const Padding(
                          padding: EdgeInsets.all(18),
                          child: Text(
                            'Tracing your money…',
                            style: TextStyle(color: Color(0xFFC7FF4A)),
                          ),
                        );
                      }
                      final message = _messages[index];
                      return Align(
                        alignment: message.user
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(16),
                          constraints: const BoxConstraints(maxWidth: 520),
                          decoration: BoxDecoration(
                            color: message.user
                                ? const Color(0xFFC7FF4A)
                                : Colors.white.withValues(alpha: .07),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (message.user)
                                Text(
                                  message.text,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    height: 1.45,
                                  ),
                                )
                              else
                                MarkdownBody(
                                  data: mobileFriendlyMarkdown(message.text),
                                  selectable: true,
                                  styleSheet: MarkdownStyleSheet(
                                    p: const TextStyle(
                                      color: Colors.white,
                                      height: 1.5,
                                      fontSize: 14,
                                    ),
                                    strong: const TextStyle(
                                      color: Color(0xFFC7FF4A),
                                      fontWeight: FontWeight.w800,
                                    ),
                                    em: const TextStyle(
                                      color: Color(0xFF65EAD1),
                                      fontStyle: FontStyle.italic,
                                    ),
                                    listBullet: const TextStyle(
                                      color: Color(0xFFC7FF4A),
                                      fontWeight: FontWeight.w800,
                                    ),
                                    code: TextStyle(
                                      color: const Color(0xFF65EAD1),
                                      backgroundColor: Colors.black.withValues(
                                        alpha: .35,
                                      ),
                                      fontFamily: 'monospace',
                                    ),
                                    blockquoteDecoration: const BoxDecoration(
                                      border: Border(
                                        left: BorderSide(
                                          color: Color(0xFFC7FF4A),
                                          width: 3,
                                        ),
                                      ),
                                    ),
                                    blockquotePadding: const EdgeInsets.only(
                                      left: 12,
                                    ),
                                  ),
                                ),
                              if (message.sources > 0) ...[
                                const SizedBox(height: 10),
                                Text(
                                  '${message.verified ? 'Verified' : 'Checked'} against '
                                  '${message.sources} matching local records',
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: !_thinking,
                  onSubmitted: (_) => _ask(),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Ask about your money or control the app…',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: .07),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(99),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _thinking ? null : _ask,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFC7FF4A),
                  foregroundColor: Colors.black,
                  fixedSize: const Size(52, 52),
                ),
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Converts model-produced Markdown tables into stacked, phone-friendly rows.
/// The prompt forbids tables, but this keeps responses readable if a model
/// ignores that instruction.
String mobileFriendlyMarkdown(String input) {
  final lines = input.split('\n');
  final output = <String>[];
  var index = 0;
  List<String> cells(String line) => line
      .split('|')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();
  bool separator(String line) {
    final values = cells(line);
    return values.isNotEmpty &&
        values.every((value) => RegExp(r'^:?-{3,}:?$').hasMatch(value));
  }

  while (index < lines.length) {
    if (index + 1 < lines.length &&
        lines[index].contains('|') &&
        separator(lines[index + 1])) {
      final headers = cells(lines[index]);
      index += 2;
      while (index < lines.length && lines[index].contains('|')) {
        final values = cells(lines[index]);
        final fields = <String>[];
        for (
          var cellIndex = 0;
          cellIndex < values.length && cellIndex < headers.length;
          cellIndex++
        ) {
          fields.add('**${headers[cellIndex]}:** ${values[cellIndex]}');
        }
        if (fields.isNotEmpty) output.add('- ${fields.join(' · ')}');
        index++;
      }
      continue;
    }
    output.add(lines[index]);
    index++;
  }
  return output.join('\n');
}
