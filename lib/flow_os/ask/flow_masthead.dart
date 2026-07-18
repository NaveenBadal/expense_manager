import 'package:flutter/material.dart';

import '../foundation/flow_color.dart';

class FlowMasthead extends StatelessWidget {
  const FlowMasthead({
    super.key,
    required this.connected,
    required this.thinking,
    required this.onStatePressed,
    this.onClear,
  });
  final bool connected;
  final bool thinking;
  final VoidCallback onStatePressed;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  thinking
                      ? 'Looking through your activity'
                      : 'Your money, made clearer',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: FlowColor.quiet(context),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Ask',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontFamily: 'Space Grotesk',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (onClear != null)
            _Action(
              icon: Icons.delete_sweep_outlined,
              label: 'Clear conversation',
              onTap: onClear!,
            ),
          const SizedBox(width: 4),
          _Action(
            icon: connected ? Icons.sync_rounded : Icons.link_rounded,
            label: connected ? 'Check messages' : 'Connect intelligence',
            onTap: onStatePressed,
            emphasized: !connected,
          ),
        ],
      ),
    ),
  );
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.emphasized = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool emphasized;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: IconButton(
      tooltip: label,
      onPressed: onTap,
      icon: Icon(icon, size: 21),
      color: emphasized
          ? FlowColor.intelligence(context)
          : FlowColor.quiet(context),
    ),
  );
}
