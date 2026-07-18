import 'package:flutter/material.dart';

import '../foundation/flow_color.dart';
import '../primitives/coordinate_label.dart';
import '../primitives/cut_surface.dart';
import '../primitives/loom_mark.dart';

class AgentDecisionSheet extends StatelessWidget {
  const AgentDecisionSheet({
    super.key,
    required this.title,
    required this.description,
    required this.confirmLabel,
    this.notice,
    this.destructive = false,
  });

  final String title;
  final String description;
  final String confirmLabel;
  final String? notice;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final signal = destructive ? FlowColor.coral : FlowColor.proof;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                LoomMark(
                  size: 44,
                  state: destructive ? LoomState.review : LoomState.checking,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CoordinateLabel(
                        destructive
                            ? 'AGENT / DESTRUCTIVE DECISION'
                            : 'AGENT / USER AUTHORITY',
                        color: signal,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title.toUpperCase(),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: FlowColor.content(context),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            CutSurface(
              cut: 10,
              color: FlowColor.plane(context),
              accent: signal,
              padding: const EdgeInsets.all(15),
              child: Text(
                description,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: FlowColor.content(context),
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (notice != null) ...[
              const SizedBox(height: 11),
              Text(
                notice!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: FlowColor.quiet(context),
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _DecisionPort(
                    label: 'CANCEL',
                    onTap: () => Navigator.pop(context, false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _DecisionPort(
                    label: confirmLabel.toUpperCase(),
                    signal: signal,
                    active: true,
                    onTap: () => Navigator.pop(context, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DecisionPort extends StatelessWidget {
  const _DecisionPort({
    required this.label,
    required this.onTap,
    this.signal = FlowColor.proof,
    this.active = false,
  });
  final String label;
  final VoidCallback onTap;
  final Color signal;
  final bool active;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: CutSurface(
        cut: 8,
        color: active ? signal : FlowColor.plane(context),
        accent: active ? signal : FlowColor.rule(context),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
        child: Center(
          child: Text(
            active ? '$label →' : label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? Colors.white : FlowColor.quiet(context),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: .7,
            ),
          ),
        ),
      ),
    ),
  );
}
