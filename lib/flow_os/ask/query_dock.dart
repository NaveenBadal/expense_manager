import 'package:flutter/material.dart';

import '../foundation/flow_color.dart';

class QueryDock extends StatelessWidget {
  const QueryDock({
    super.key,
    required this.controller,
    required this.enabled,
    required this.connected,
    required this.onAsk,
  });
  final TextEditingController controller;
  final bool enabled;
  final bool connected;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: FlowColor.raised(context),
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(18),
        topRight: Radius.circular(18),
        bottomLeft: Radius.circular(18),
        bottomRight: Radius.circular(15),
      ),
      border: Border.all(
        color: enabled
            ? FlowColor.intelligence(context).withValues(alpha: .42)
            : FlowColor.rule(context),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  enabled: enabled,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => onAsk(),
                  style: Theme.of(context).textTheme.bodyLarge,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: connected
                        ? 'Ask about your money'
                        : 'Connect intelligence to ask',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.only(
                      top: 4,
                      bottom: 5,
                      right: 8,
                    ),
                  ),
                ),
                Text(
                  connected
                      ? 'Answers use only the activity you allow'
                      : 'Your activity stays private',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: FlowColor.quiet(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            enabled: enabled,
            label: 'Send question',
            child: IconButton.filled(
              onPressed: enabled ? onAsk : null,
              tooltip: 'Send',
              style: IconButton.styleFrom(
                minimumSize: const Size(48, 48),
                backgroundColor: FlowColor.intelligence(context),
                disabledBackgroundColor: FlowColor.plane(context),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.arrow_upward_rounded, size: 21),
            ),
          ),
        ],
      ),
    ),
  );
}
