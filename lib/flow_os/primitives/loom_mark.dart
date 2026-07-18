import 'package:flutter/material.dart';

import '../foundation/flow_color.dart';

enum LoomState { ready, checking, proven, review, offline }

/// Quiet Current mark: a financial line and its shorter understanding line.
class LoomMark extends StatelessWidget {
  const LoomMark({
    super.key,
    this.size = 44,
    this.state = LoomState.ready,
    this.progress,
  });
  final double size;
  final LoomState state;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      LoomState.proven => FlowColor.income(context),
      LoomState.review => FlowColor.review(context),
      LoomState.offline => FlowColor.quiet(context),
      _ => FlowColor.intelligence(context),
    };
    return Semantics(
      image: true,
      label: switch (state) {
        LoomState.checking => 'Checking activity',
        LoomState.proven => 'Confirmed',
        LoomState.review => 'Needs review',
        LoomState.offline => 'Not connected',
        _ => 'Fund Flow ready',
      },
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(size),
          painter: _CurrentPainter(
            color: color,
            quiet: FlowColor.rule(context),
            progress: progress,
          ),
        ),
      ),
    );
  }
}

class _CurrentPainter extends CustomPainter {
  const _CurrentPainter({
    required this.color,
    required this.quiet,
    this.progress,
  });
  final Color color;
  final Color quiet;
  final double? progress;
  @override
  void paint(Canvas canvas, Size size) {
    final active = (progress ?? 1).clamp(0.0, 1.0);
    final stroke = size.width * .075;
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final muted = Paint()
      ..color = quiet
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final left = size.width * .13;
    final right = size.width * .87;
    final y1 = size.height * .40;
    final y2 = size.height * .62;
    canvas.drawLine(Offset(left, y1), Offset(right, y1), muted);
    canvas.drawLine(
      Offset(left, y1),
      Offset(left + (right - left) * active, y1),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * .39, y2),
      Offset(size.width * .76, y2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CurrentPainter old) =>
      old.color != color || old.quiet != quiet || old.progress != progress;
}
