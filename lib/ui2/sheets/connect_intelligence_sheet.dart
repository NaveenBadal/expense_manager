import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/app_state.dart';
import '../../domain/preferences.dart';
import '../components/flow_field.dart';
import '../tokens/flow_metrics.dart';
import '../tokens/flow_palette.dart';

/// Connecting the AI provider.
///
/// One field in the common path — the key — with endpoint and model choices
/// behind a disclosure, because almost everyone connects with the defaults
/// and three extra fields would make pasting a key look like configuration.
class ConnectIntelligenceSheet extends ConsumerStatefulWidget {
  const ConnectIntelligenceSheet({super.key});

  @override
  ConsumerState<ConnectIntelligenceSheet> createState() => _State();
}

class _State extends ConsumerState<ConnectIntelligenceSheet> {
  final _key = TextEditingController();
  late final _endpoint = TextEditingController(
    text: ref.read(appControllerProvider).value?.preferences.aiEndpoint,
  );
  late final _model = TextEditingController(
    text: ref.read(appControllerProvider).value?.preferences.aiModel,
  );
  late final _chatModel = TextEditingController(
    text: ref.read(appControllerProvider).value?.preferences.aiChatModel,
  );
  bool _showKey = false;
  bool _advanced = false;
  bool _keyMissing = false;

  @override
  void dispose() {
    _key.dispose();
    _endpoint.dispose();
    _model.dispose();
    _chatModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flow = context.flow;
    final text = Theme.of(context).textTheme;
    final async = ref.watch(appControllerProvider);
    final checking = async.value?.aiConnection == AiConnection.checking;
    final error = async.value?.error;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(FlowSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Connect intelligence', style: text.titleLarge),
            const SizedBox(height: FlowSpace.sm),
            Text(
              'Questions and unseen message text you choose to analyze are '
              'sent to this provider. Your normalized activity stays on '
              'this device.',
              style: text.bodyMedium?.copyWith(color: flow.inkSoft),
            ),
            const SizedBox(height: FlowSpace.lg),
            FlowField(
              controller: _key,
              label: 'Ollama API key',
              hint: 'Paste your key',
              obscureText: !_showKey,
              error: _keyMissing ? 'Enter an API key.' : error,
              onChanged: (_) {
                if (_keyMissing) setState(() => _keyMissing = false);
              },
              suffix: IconButton(
                tooltip: _showKey ? 'Hide key' : 'Show key',
                onPressed: () => setState(() => _showKey = !_showKey),
                icon: Icon(
                  _showKey
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                  color: flow.inkSoft,
                ),
              ),
            ),
            const SizedBox(height: FlowSpace.sm),
            TextButton.icon(
              onPressed: () => setState(() => _advanced = !_advanced),
              style: TextButton.styleFrom(
                foregroundColor: flow.inkSoft,
                padding: const EdgeInsets.symmetric(horizontal: FlowSpace.sm),
              ),
              icon: Icon(
                _advanced
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 18,
              ),
              label: Text(
                _advanced ? 'Hide advanced options' : 'Advanced options',
              ),
            ),
            if (_advanced) ...[
              const SizedBox(height: FlowSpace.sm),
              FlowField(
                controller: _endpoint,
                label: 'Endpoint',
                hint: 'https://ollama.com',
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: FlowSpace.md),
              FlowField(
                controller: _model,
                label: 'Parsing model',
                hint: defaultParsingModel,
                helper:
                    'Reads transaction messages. A small fast model is best: '
                    'extraction is a single structured pass.',
              ),
              const SizedBox(height: FlowSpace.md),
              FlowField(
                controller: _chatModel,
                label: 'Chat model',
                hint: defaultChatModel,
                helper:
                    'Answers your questions. A stronger model reaches an '
                    'answer in fewer turns, which is usually faster end '
                    'to end.',
              ),
            ],
            const SizedBox(height: FlowSpace.xl),
            FilledButton.icon(
              onPressed: checking ? null : _connect,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(FlowDensity.minimumTarget),
                backgroundColor: flow.accent,
                foregroundColor: flow.onAccent,
                shape: const RoundedRectangleBorder(
                  borderRadius: FlowRadius.sm,
                ),
              ),
              icon: checking
                  ? SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: flow.onAccent,
                      ),
                    )
                  : const Icon(Icons.link_rounded, size: 18),
              label: Text(checking ? 'Checking connection…' : 'Connect'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _connect() async {
    if (_key.text.trim().isEmpty) {
      setState(() => _keyMissing = true);
      return;
    }
    final ok = await ref
        .read(appControllerProvider.notifier)
        .connectAi(
          key: _key.text.trim(),
          endpoint: _endpoint.text.trim(),
          model: _model.text.trim(),
          chatModel: _chatModel.text.trim().isEmpty
              ? null
              : _chatModel.text.trim(),
        );
    if (ok && mounted) Navigator.pop(context);
  }
}
