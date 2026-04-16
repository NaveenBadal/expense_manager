import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/expense_provider.dart';
import '../models/ai_log.dart';

class LogsScreen extends ConsumerWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(aiLogProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Request Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear Logs?'),
                  content: const Text('This will delete all AI request and response logs.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () {
                        ref.read(aiLogProvider.notifier).clearLogs();
                        Navigator.pop(context);
                      },
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: logsAsync.when(
        data: (logs) {
          if (logs.isEmpty) {
            return const Center(child: Text('No AI logs found.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return _buildLogCard(context, log);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildLogCard(BuildContext context, AiLog log) {
    final isError = log.status.startsWith('Error');
    final timestamp = DateFormat('MMM dd, HH:mm:ss').format(log.timestamp);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isError ? Colors.red.withValues(alpha: 0.2) : Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      child: ExpansionTile(
        leading: Icon(
          isError ? Icons.error_outline : Icons.check_circle_outline,
          color: isError ? Colors.red : Colors.green,
        ),
        title: Text(
          isError ? 'Request Failed' : 'AI Extraction Successful',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(timestamp),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSection(context, 'Prompt', log.requestPrompt),
                const SizedBox(height: 16),
                _buildSection(context, 'Response', log.responseBody),
                const SizedBox(height: 16),
                _buildSection(context, 'Status', log.status),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            content,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ],
    );
  }
}
