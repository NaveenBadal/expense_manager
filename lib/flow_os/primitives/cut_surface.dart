import 'package:flutter/material.dart';

import '../foundation/flow_color.dart';

/// Compatibility surface for the new soft ledger plane.
class CutSurface extends StatelessWidget {
  const CutSurface({
    super.key,
    required this.child,
    this.color,
    this.accent,
    this.padding = const EdgeInsets.all(16),
    this.cut = 12,
    this.border = true,
  });
  final Widget child;
  final Color? color;
  final Color? accent;
  final EdgeInsetsGeometry padding;
  final double cut;
  final bool border;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color ?? FlowColor.plane(context),
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(cut + 4),
        topRight: Radius.circular(cut + 4),
        bottomLeft: Radius.circular(cut + 4),
        bottomRight: Radius.circular(cut + 1),
      ),
      border: border
          ? Border.all(color: accent ?? FlowColor.rule(context))
          : null,
    ),
    child: Padding(padding: padding, child: child),
  );
}
