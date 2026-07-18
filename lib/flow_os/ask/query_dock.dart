import 'package:flutter/material.dart';

import '../foundation/flow_color.dart';
import '../primitives/cut_surface.dart';
import '../primitives/loom_mark.dart';

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
  Widget build(BuildContext context) => CutSurface(
    cut: 14,
    color: FlowColor.raised(context),
    accent: enabled ? FlowColor.proof : FlowColor.rule(context),
    padding: const EdgeInsets.fromLTRB(15, 9, 8, 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                enabled ? 'QUERY / EVIDENCE-BOUND' : 'QUERY / LOCKED',
                style: TextStyle(
                  color: enabled ? FlowColor.proof : FlowColor.quiet(context),
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              TextField(
                controller: controller,
                enabled: enabled,
                onSubmitted: (_) => onAsk(),
                minLines: 1,
                maxLines: 4,
                style: TextStyle(
                  color: FlowColor.content(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  filled: false,
                  contentPadding: const EdgeInsets.only(top: 5, right: 10),
                  hintText: connected
                      ? 'Ask what your money means…'
                      : 'Connect intelligence to begin',
                  hintStyle: TextStyle(color: FlowColor.quiet(context)),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                ),
              ),
            ],
          ),
        ),
        Semantics(
          button: true,
          enabled: enabled,
          label: 'Ask Flow',
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? onAsk : null,
            child: Container(
              width: 54,
              height: 54,
              color: enabled ? FlowColor.loom : FlowColor.plane(context),
              alignment: Alignment.center,
              child: enabled
                  ? const LoomMark(size: 26)
                  : Icon(
                      Icons.lock_outline_rounded,
                      size: 20,
                      color: FlowColor.quiet(context),
                    ),
            ),
          ),
        ),
      ],
    ),
  );
}
