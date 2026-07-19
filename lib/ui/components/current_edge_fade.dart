import 'package:flutter/material.dart';

/// Softens where scrolling content meets a fixed edge.
///
/// Without this a row slides under the header and is cut mid-glyph, which
/// reads as a rendering fault rather than as content continuing. Paper does
/// not end in a hard line, and neither should a column of figures.
///
/// Implemented as a shader mask on alpha, so it works over any background and
/// needs no colour matched to the surface behind it.
class CurrentEdgeFade extends StatelessWidget {
  const CurrentEdgeFade({
    super.key,
    required this.child,
    this.top = 22,
    this.bottom = 22,
  });

  final Widget child;

  /// Fade height in logical pixels. Zero disables that edge.
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final height = box.maxHeight;
      if (!height.isFinite || height <= 0) return child;
      final topStop = (top / height).clamp(0.0, .5);
      final bottomStop = (bottom / height).clamp(0.0, .5);
      return ShaderMask(
        // dstIn keeps the child's colour and multiplies its alpha by the
        // gradient, so only opacity is affected.
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0x00000000),
            Color(0xFF000000),
            Color(0xFF000000),
            Color(0x00000000),
          ],
          stops: [0, topStop, 1 - bottomStop, 1],
        ).createShader(rect),
        child: child,
      );
    },
  );
}
