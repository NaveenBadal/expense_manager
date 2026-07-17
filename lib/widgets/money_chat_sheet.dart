import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/expense_provider.dart';
import '../providers/assistant_conversation_provider.dart';
import '../services/app_control_service.dart';
import '../services/local_money_mcp.dart';
import '../services/money_chat_service.dart';
import '../theme/app_tokens.dart';
import '../screens/settings_screen.dart';

class MoneyChatSheet extends ConsumerStatefulWidget {
  const MoneyChatSheet({
    super.key,
    this.initialPrompt,
    this.fullScreen = false,
    this.onOpenSettings,
  });
  final String? initialPrompt;
  final bool fullScreen;
  final VoidCallback? onOpenSettings;
  @override
  ConsumerState<MoneyChatSheet> createState() => _MoneyChatSheetState();
}

class _MoneyChatSheetState extends ConsumerState<MoneyChatSheet> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _thinking = false;
  String? _failedQuestion;
  bool _didScrollToInitialHistory = false;
  String _stage = 'Understanding your request…';
  late final LocalMoneyMcpClient _mcp;

  static const _prompts = <(IconData, String)>[
    (Icons.calendar_month_rounded, 'Summarize this month'),
    (Icons.rule_rounded, 'Find transactions that need review'),
    (Icons.savings_outlined, 'Where can I spend less?'),
  ];

  @override
  void initState() {
    super.initState();
    _mcp = LocalMoneyMcpClient(
      LocalMoneyMcpServer(
        ref.read(databaseProvider),
        appToolHandler: _handleAppTool,
      ),
    );
    final prompt = widget.initialPrompt?.trim();
    if (prompt != null && prompt.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ask(prompt));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToLatest({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      if (animate) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
        return;
      }
      _jumpToLatestAfterLayout(3);
    });
  }

  void _jumpToLatestAfterLayout(int remainingFrames) {
    if (!mounted || !_scrollController.hasClients) return;
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    if (remainingFrames <= 1) return;

    // A lazily built list can discover a larger extent after the first jump.
    // Repeat across layout frames so a long conversation reaches its true end.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _jumpToLatestAfterLayout(remainingFrames - 1),
    );
    WidgetsBinding.instance.scheduleFrame();
  }

  Future<void> _ask([String? suggested, bool recordUser = true]) async {
    final question = (suggested ?? _controller.text).trim();
    if (question.isEmpty || _thinking) return;
    final history = ref.read(assistantConversationProvider).value ?? const [];
    _controller.clear();
    setState(() {
      _thinking = true;
      _failedQuestion = null;
      _stage = 'Understanding your request…';
    });
    if (recordUser) {
      await ref.read(assistantConversationProvider.notifier).addUser(question);
    }
    _scrollToLatest();
    try {
      final service = MoneyChatService(
        ref.read(ollamaCloudProvider),
        mcpClient: _mcp,
        approveTool: _approveTool,
        onProgress: (stage) {
          if (mounted) setState(() => _stage = stage);
        },
        onToolCompleted: (name, result) {
          if (result['changed'] != true) return;
          if ({
            'create_transaction',
            'update_transaction',
            'delete_transaction',
          }.contains(name)) {
            ref.invalidate(expenseListProvider);
          }
        },
      );
      final answer = await service.ask(question, history: history);
      if (!mounted) return;
      await ref
          .read(assistantConversationProvider.notifier)
          .addAssistant(
            text: answer.text,
            sources: answer.checkedRecords,
            verified: answer.verified,
            filterDetails: jsonEncode(
              answer.appliedFilters.map((filter) => filter.toJson()).toList(),
            ),
          );
      if (!mounted) return;
      setState(() {});
      _scrollToLatest();
    } catch (_) {
      if (!mounted) return;
      setState(() => _failedQuestion = question);
      _scrollToLatest();
    } finally {
      if (mounted) setState(() => _thinking = false);
    }
  }

  Future<bool> _approveTool(String name, Map<String, dynamic> arguments) async {
    final action = switch (name) {
      'set_app_lock' =>
        arguments['enabled'] == true
            ? 'enable the app lock'
            : 'disable the app lock',
      'set_notification_capture' =>
        arguments['enabled'] == true
            ? 'enable notification transaction capture'
            : 'disable notification transaction capture',
      'create_transaction' => 'create this transaction',
      'update_transaction' => 'change transaction #${arguments['id'] ?? ''}',
      'delete_transaction' =>
        'permanently delete transaction #${arguments['id'] ?? ''}',
      'reanalyze_transaction_sms' =>
        'send transaction #${arguments['id'] ?? ''} original SMS to your configured Ollama endpoint for re-analysis',
      _ => 'perform this sensitive action',
    };
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Confirm app change'),
            content: Text('Allow Flow to $action?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _openSettings() {
    final callback = widget.onOpenSettings;
    if (callback != null) {
      callback();
      return;
    }
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  Future<void> _clearConversation() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.delete_sweep_outlined),
            title: const Text('Clear conversation?'),
            content: const Text(
              'This removes your Ask Flow history from this device.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Clear'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    await ref.read(assistantConversationProvider.notifier).clear();
    if (mounted) setState(() => _failedQuestion = null);
  }

  Future<void> _copyAnswer(String answer) async {
    await Clipboard.setData(ClipboardData(text: answer));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Answer copied')));
  }

  Future<Map<String, dynamic>> _handleAppTool(
    String name,
    Map<String, dynamic> arguments,
  ) async {
    final service = ref.read(appControlServiceProvider);
    final result = await service.handle(name, arguments);
    if (result['undo_available'] == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('App setting changed'),
          action: SnackBarAction(label: 'Undo', onPressed: service.undoLast),
        ),
      );
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(assistantConversationProvider).value ?? const [];
    final connected = ref.watch(ollamaApiKeyProvider).trim().isNotEmpty;
    if (messages.isNotEmpty && !_didScrollToInitialHistory) {
      _didScrollToInitialHistory = true;
      _scrollToLatest(animate: false);
    }
    final scheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final contentInset = screenWidth > 760 ? (screenWidth - 720) / 2 : 20.0;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Ask Flow'),
        actions: [
          if (messages.isNotEmpty)
            IconButton(
              tooltip: 'Clear conversation',
              onPressed: _clearConversation,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(contentInset, 14, contentInset, 16),
          child: Column(
            children: [
              Expanded(
                child: messages.isEmpty
                    ? ListView(
                        controller: _scrollController,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 32, 4, 26),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: scheme.primaryContainer,
                                    borderRadius: AppRadius.all(AppRadius.lg),
                                  ),
                                  child: Icon(
                                    Icons.auto_awesome_outlined,
                                    size: 28,
                                    color: scheme.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'How can I help with your money?',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Ask about transactions, find patterns, correct details, or change app settings.',
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          if (!connected)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Material(
                                color: scheme.tertiaryContainer,
                                shape: ExpressiveShape.card(
                                  radius: AppRadius.xl,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: _openSettings,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.cloud_outlined,
                                          color: scheme.onTertiaryContainer,
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Connect Ask Flow',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleSmall
                                                    ?.copyWith(
                                                      color: scheme
                                                          .onTertiaryContainer,
                                                    ),
                                              ),
                                              Text(
                                                'Add your Ollama Cloud key in Settings.',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: scheme
                                                          .onTertiaryContainer,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          color: scheme.onTertiaryContainer,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          for (final prompt in _prompts)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Material(
                                color: scheme.surfaceContainerHigh,
                                shape: ExpressiveShape.card(
                                  radius: AppRadius.xl,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: connected
                                      ? () => _ask(prompt.$2)
                                      : _openSettings,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          prompt.$1,
                                          size: 20,
                                          color: scheme.primary,
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Text(
                                            prompt.$2,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyLarge,
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_outward_rounded,
                                          size: 18,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.only(top: 8, bottom: 16),
                        itemCount:
                            messages.length +
                            (_thinking || _failedQuestion != null ? 1 : 0),
                        itemBuilder: (_, index) {
                          if (index == messages.length) {
                            if (!_thinking) {
                              return _RetryMessage(
                                onRetry: () => _ask(_failedQuestion, false),
                              );
                            }
                            return Padding(
                              padding: const EdgeInsets.all(18),
                              child: Row(
                                children: [
                                  SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: scheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _stage,
                                      style: TextStyle(color: scheme.primary),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          final message = messages[index];
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
                                    ? scheme.primaryContainer
                                    : scheme.surfaceContainerHigh,
                                borderRadius: ExpressiveShape.playful(index),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (message.user)
                                    Text(
                                      message.text,
                                      style: TextStyle(
                                        color: scheme.onPrimaryContainer,
                                        height: 1.45,
                                      ),
                                    )
                                  else
                                    MarkdownBody(
                                      data: mobileFriendlyMarkdown(
                                        message.text,
                                      ),
                                      selectable: true,
                                      styleSheet: MarkdownStyleSheet(
                                        p: TextStyle(
                                          color: scheme.onSurface,
                                          height: 1.5,
                                          fontSize: 14,
                                        ),
                                        strong: TextStyle(
                                          color: scheme.primary,
                                          fontWeight: FontWeight.w800,
                                        ),
                                        em: TextStyle(
                                          color: scheme.secondary,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        listBullet: TextStyle(
                                          color: scheme.primary,
                                          fontWeight: FontWeight.w800,
                                        ),
                                        code: TextStyle(
                                          color: scheme.onSurface,
                                          backgroundColor:
                                              scheme.surfaceContainerHighest,
                                          fontFamily: 'monospace',
                                        ),
                                        blockquoteDecoration: BoxDecoration(
                                          border: Border(
                                            left: BorderSide(
                                              color: scheme.primary,
                                              width: 3,
                                            ),
                                          ),
                                        ),
                                        blockquotePadding:
                                            const EdgeInsets.only(left: 12),
                                      ),
                                    ),
                                  if (message.sources > 0) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Icon(
                                          message.verified
                                              ? Icons.verified_outlined
                                              : Icons.fact_check_outlined,
                                          size: 16,
                                          color: scheme.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            '${message.verified ? 'Verified' : 'Checked'} with ${message.sources} local records',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (message.filterDetails.isNotEmpty)
                                      Theme(
                                        data: Theme.of(context).copyWith(
                                          dividerColor: Colors.transparent,
                                        ),
                                        child: ExpansionTile(
                                          tilePadding: EdgeInsets.zero,
                                          childrenPadding: EdgeInsets.zero,
                                          dense: true,
                                          title: Text(
                                            'How this was answered',
                                            style: TextStyle(
                                              color: scheme.onSurfaceVariant,
                                              fontSize: 11,
                                            ),
                                          ),
                                          children: [
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                _formatFilterDetails(
                                                  message.filterDetails,
                                                ),
                                                style: TextStyle(
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                  fontSize: 11,
                                                  height: 1.45,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                  if (!message.user) ...[
                                    const SizedBox(height: 6),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: IconButton(
                                        tooltip: 'Copy answer',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () =>
                                            _copyAnswer(message.text),
                                        icon: const Icon(
                                          Icons.content_copy_rounded,
                                          size: 18,
                                        ),
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
                      enabled: connected && !_thinking,
                      onSubmitted: (_) => _ask(),
                      decoration: InputDecoration(
                        hintText: connected
                            ? 'Ask about your activity…'
                            : 'Connect Ask Flow in Settings',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: !connected || _thinking ? null : _ask,
                    style: IconButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      fixedSize: const Size(52, 52),
                    ),
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RetryMessage extends StatelessWidget {
  const _RetryMessage({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: scheme.errorContainer,
        shape: ExpressiveShape.card(radius: AppRadius.xl),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
          child: Row(
            children: [
              Icon(Icons.wifi_off_rounded, color: scheme.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Flow couldn’t answer',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                    ),
                    Text(
                      'Nothing was changed. Check your connection and try again.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
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

String _formatFilterDetails(String raw) {
  try {
    final filters = jsonDecode(raw) as List<dynamic>;
    if (filters.isEmpty) return 'No transaction filter was needed.';
    return filters
        .map((entry) {
          final filter = (entry as Map).cast<String, dynamic>();
          final parts = <String>[];
          if (filter['from'] != null || filter['to'] != null) {
            parts.add(
              'Date: ${filter['from'] ?? 'start'} to ${filter['to'] ?? 'now'}',
            );
          }
          for (final key in [
            'merchant',
            'category',
            'direction',
            'currency',
            'text',
          ]) {
            if (filter[key] != null) {
              parts.add(
                '${key[0].toUpperCase()}${key.substring(1)}: ${filter[key]}',
              );
            }
          }
          return parts.isEmpty ? 'All matching transactions' : parts.join('\n');
        })
        .join('\n\n');
  } catch (_) {
    return 'Verified local transaction filters were applied.';
  }
}
