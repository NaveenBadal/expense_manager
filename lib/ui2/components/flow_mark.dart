import 'package:flutter/material.dart';

import '../tokens/flow_palette.dart';

/// The Fund Flow mark: two strokes of progress against a quiet baseline.
class FlowMark extends StatelessWidget {
  const FlowMark({super.key, this.size = 32, this.color});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final flow = context.flow;
    return Semantics(
      image: true,
      label: 'Fund Flow',
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(size),
          painter: _MarkPainter(color: color ?? flow.accent, quiet: flow.line),
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.color, required this.quiet});
  final Color color;
  final Color quiet;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width * .075;
    final muted = Paint()
      ..color = quiet
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    final active = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * .1, size.height * .38),
      Offset(size.width * .9, size.height * .38),
      muted,
    );
    canvas.drawLine(
      Offset(size.width * .1, size.height * .38),
      Offset(size.width * .72, size.height * .38),
      active,
    );
    canvas.drawLine(
      Offset(size.width * .38, size.height * .64),
      Offset(size.width * .78, size.height * .64),
      active,
    );
  }

  @override
  bool shouldRepaint(covariant _MarkPainter old) =>
      old.color != color || old.quiet != quiet;
}
