import 'package:flutter/material.dart';

import '../foundation/flow_color.dart';

class CoordinateLabel extends StatelessWidget {
  const CoordinateLabel(this.text, {super.key, this.color, this.line = false});

  final String text;
  final Color? color;
  final bool line;

  @override
  Widget build(BuildContext context) {
    final effective = color ?? FlowColor.proof;
    return Row(
      mainAxisSize: line ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Container(width: 5, height: 5, color: effective),
        const SizedBox(width: 8),
        Flexible(
          fit: FlexFit.loose,
          child: Text(
            text.toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.fade,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: effective,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.15,
              height: 1.2,
            ),
          ),
        ),
        if (line) ...[
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              color: effective.withValues(alpha: .24),
            ),
          ),
        ],
      ],
    );
  }
}
