import 'package:flutter/material.dart';

import '../foundation/flow_color.dart';
import '../primitives/coordinate_label.dart';
import '../primitives/loom_mark.dart';

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
  Widget build(BuildContext context) {
    final state = thinking
        ? LoomState.checking
        : connected
        ? LoomState.ready
        : LoomState.offline;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
        child: Column(
          children: [
            Row(
              children: [
                LoomMark(size: 34, state: state),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CoordinateLabel('FIELD / 00'),
                      SizedBox(height: 2),
                      Text(
                        'FLOW',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onClear != null)
                  _MastheadAction(
                    semantics: 'Clear conversation',
                    label: 'CLEAR',
                    onTap: onClear!,
                  ),
                const SizedBox(width: 6),
                _MastheadAction(
                  semantics: connected
                      ? 'Analyze transaction messages'
                      : 'Connect AI',
                  label: connected ? 'INGEST' : 'CONNECT',
                  active: connected,
                  onTap: onStatePressed,
                ),
              ],
            ),
            const SizedBox(height: 11),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FractionallySizedBox(
                widthFactor: connected ? 1 : .22,
                child: Container(
                  height: 2,
                  color: connected ? FlowColor.proof : FlowColor.rule(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MastheadAction extends StatelessWidget {
  const _MastheadAction({
    required this.semantics,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final String semantics;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semantics,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 52, minHeight: 44),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: active ? FlowColor.proof : FlowColor.rule(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? FlowColor.proof : FlowColor.content(context),
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: .8,
          ),
        ),
      ),
    ),
  );
}
