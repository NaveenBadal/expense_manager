import 'package:flutter/material.dart';

import '../foundation/flow_color.dart';

enum LoomState { ready, checking, proven, review, offline }

/// Flow's only intelligence mark. It is deliberately static and schedules no
/// frames while idle.
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
    final main = switch (state) {
      LoomState.proven => FlowColor.mint,
      LoomState.review => FlowColor.amber,
      LoomState.offline => FlowColor.quiet(context),
      _ => FlowColor.loomBright,
    };
    return Semantics(
      image: true,
      label: 'Flow ${state.name}',
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(size),
          painter: _LoomPainter(
            main: main,
            proof: FlowColor.proof,
            progress: progress,
          ),
        ),
      ),
    );
  }
}

class _LoomPainter extends CustomPainter {
  const _LoomPainter({required this.main, required this.proof, this.progress});

  final Color main;
  final Color proof;
  final double? progress;

  static const _nodes = <(double, double, double)>[
    (.24, .12, .7),
    (.50, .08, .9),
    (.76, .12, .7),
    (.17, .31, .65),
    (.50, .28, 1.05),
    (.83, .31, .65),
    (.10, .52, .55),
    (.35, .49, .8),
    (.50, .50, 1.18),
    (.65, .49, .8),
    (.90, .52, .55),
    (.17, .72, .65),
    (.50, .71, 1.05),
    (.83, .72, .65),
    (.24, .90, .7),
    (.50, .94, .9),
    (.76, .90, .7),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final threadPaint = Paint()
      ..color = main.withValues(alpha: .2)
      ..strokeWidth = size.width * .035
      ..strokeCap = StrokeCap.square;
    for (final x in const [.35, .5, .65]) {
      canvas.drawLine(
        Offset(size.width * x, size.height * .12),
        Offset(size.width * x, size.height * .9),
        threadPaint,
      );
    }
    final enabled = progress == null
        ? _nodes.length
        : (_nodes.length * progress!.clamp(0, 1)).ceil();
    for (var index = 0; index < _nodes.length; index++) {
      final node = _nodes[index];
      final centerThread = (node.$1 - .5).abs() < .02;
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(size.width * node.$1, size.height * node.$2),
          width: size.width * .09 * node.$3,
          height: size.width * .09 * node.$3,
        ),
        Paint()
          ..color = index < enabled
              ? (centerThread ? proof : main).withValues(alpha: .92)
              : main.withValues(alpha: .14),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LoomPainter oldDelegate) =>
      oldDelegate.main != main ||
      oldDelegate.proof != proof ||
      oldDelegate.progress != progress;
}
