import 'package:flutter/material.dart';

import '../foundation/flow_color.dart';

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
  Widget build(BuildContext context) {
    final fill = color ?? FlowColor.plane(context);
    return ClipPath(
      clipper: _CutClipper(cut),
      child: CustomPaint(
        foregroundPainter: border
            ? _CutBorderPainter(cut, accent ?? FlowColor.rule(context))
            : null,
        child: ColoredBox(
          color: fill,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

Path _cutPath(Size size, double cut) => Path()
  ..moveTo(0, 0)
  ..lineTo(size.width - cut, 0)
  ..lineTo(size.width, cut)
  ..lineTo(size.width, size.height)
  ..lineTo(cut, size.height)
  ..lineTo(0, size.height - cut)
  ..close();

class _CutClipper extends CustomClipper<Path> {
  const _CutClipper(this.cut);
  final double cut;
  @override
  Path getClip(Size size) => _cutPath(size, cut);
  @override
  bool shouldReclip(covariant _CutClipper oldClipper) => oldClipper.cut != cut;
}

class _CutBorderPainter extends CustomPainter {
  const _CutBorderPainter(this.cut, this.color);
  final double cut;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    _cutPath(size, cut),
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1,
  );
  @override
  bool shouldRepaint(covariant _CutBorderPainter oldDelegate) =>
      oldDelegate.cut != cut || oldDelegate.color != color;
}
