import 'package:flutter/material.dart';

import '../foundation/flow_color.dart';

class ProofThread extends StatelessWidget {
  const ProofThread({
    super.key,
    required this.child,
    this.color,
    this.node = true,
  });

  final Widget child;
  final Color? color;
  final bool node;

  @override
  Widget build(BuildContext context) {
    final effective = color ?? FlowColor.proof;
    return Stack(
      children: [
        PositionedDirectional(
          start: 5,
          top: node ? 11 : 0,
          bottom: 0,
          width: 2,
          child: ColoredBox(color: effective.withValues(alpha: .42)),
        ),
        if (node)
          PositionedDirectional(
            start: 0,
            top: 3,
            child: Container(width: 12, height: 12, color: effective),
          ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 28),
          child: child,
        ),
      ],
    );
  }
}
