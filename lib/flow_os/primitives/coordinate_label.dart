import 'package:flutter/material.dart';

import '../foundation/flow_color.dart';

/// Transitional supporting label. New copy should be plain language.
class CoordinateLabel extends StatelessWidget {
  const CoordinateLabel(this.text, {super.key, this.color, this.line = false});
  final String text;
  final Color? color;
  final bool line;

  String get _plainText => text
      .replaceAll(RegExp(r'^[A-Z]+\s*/\s*'), '')
      .replaceAll(' / ', ' · ')
      .toLowerCase()
      .split(' ')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');

  @override
  Widget build(BuildContext context) {
    final effective = color ?? FlowColor.quiet(context);
    return Row(
      mainAxisSize: line ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 2,
          decoration: BoxDecoration(
            color: effective,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            _plainText,
            maxLines: 2,
            overflow: TextOverflow.fade,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: effective,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ),
        if (line) ...[
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              color: effective.withValues(alpha: .20),
            ),
          ),
        ],
      ],
    );
  }
}
