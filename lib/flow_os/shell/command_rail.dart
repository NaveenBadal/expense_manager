import 'package:flutter/material.dart';

import '../foundation/flow_color.dart';
import '../foundation/flow_geometry.dart';
import '../foundation/flow_motion.dart';
import '../primitives/loom_mark.dart';

class CommandRail extends StatelessWidget {
  const CommandRail({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.proofCount,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final int? proofCount;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return ColoredBox(
      color: FlowColor.canvas(context),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: SizedBox(
          height: FlowGeometry.commandRailHeight,
          child: CustomPaint(
            painter: _RailPainter(
              fill: FlowColor.raised(context),
              rule: FlowColor.rule(context),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    flex: 52,
                    child: _RailPort(
                      selected: selectedIndex == 0,
                      semantics: 'Ask Flow',
                      onTap: () => onSelected(0),
                      duration: reduce ? Duration.zero : FlowMotion.spatial,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          LoomMark(
                            size: 28,
                            state: selectedIndex == 0
                                ? LoomState.ready
                                : LoomState.offline,
                          ),
                          const SizedBox(width: 10),
                          const _PortLabel(primary: 'ASK', secondary: 'FLOW'),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 30,
                    child: _RailPort(
                      selected: selectedIndex == 1,
                      semantics: 'Proof and evidence',
                      onTap: () => onSelected(1),
                      duration: reduce ? Duration.zero : FlowMotion.spatial,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _LedgerGlyph(selected: selectedIndex == 1),
                          const SizedBox(width: 9),
                          Flexible(
                            child: _PortLabel(
                              primary: 'PROOF',
                              secondary: proofCount == null
                                  ? 'LOCAL'
                                  : '${proofCount!} EVENTS',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 18,
                    child: _RailPort(
                      selected: selectedIndex == 2,
                      semantics: 'System controls',
                      onTap: () => onSelected(2),
                      duration: reduce ? Duration.zero : FlowMotion.spatial,
                      child: _SystemGlyph(selected: selectedIndex == 2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RailPort extends StatelessWidget {
  const _RailPort({
    required this.selected,
    required this.semantics,
    required this.onTap,
    required this.duration,
    required this.child,
  });

  final bool selected;
  final String semantics;
  final VoidCallback onTap;
  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: semantics,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: duration,
        curve: FlowMotion.curve,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? FlowColor.proof : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: child,
      ),
    ),
  );
}

class _PortLabel extends StatelessWidget {
  const _PortLabel({required this.primary, required this.secondary});
  final String primary;
  final String secondary;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        primary,
        maxLines: 1,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: FlowColor.content(context),
          fontWeight: FontWeight.w900,
          letterSpacing: .8,
        ),
      ),
      Text(
        secondary,
        maxLines: 1,
        overflow: TextOverflow.fade,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: FlowColor.quiet(context),
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: .65,
        ),
      ),
    ],
  );
}

class _LedgerGlyph extends StatelessWidget {
  const _LedgerGlyph({required this.selected});
  final bool selected;
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(22, 28),
    painter: _LedgerPainter(
      color: selected ? FlowColor.proof : FlowColor.quiet(context),
    ),
  );
}

class _LedgerPainter extends CustomPainter {
  const _LedgerPainter({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width - 6, 0)
      ..lineTo(size.width, 6)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
    for (final y in const [9.0, 15.0, 21.0]) {
      canvas.drawLine(Offset(5, y), Offset(size.width - 5, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LedgerPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _SystemGlyph extends StatelessWidget {
  const _SystemGlyph({required this.selected});
  final bool selected;
  @override
  Widget build(BuildContext context) {
    final color = selected ? FlowColor.proof : FlowColor.quiet(context);
    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(width: 24, height: 2, color: color),
          Container(width: 2, height: 24, color: color),
          Container(
            width: 8,
            height: 8,
            color: FlowColor.raised(context),
            foregroundDecoration: BoxDecoration(
              border: Border.all(color: color, width: 2),
            ),
          ),
        ],
      ),
    );
  }
}

class _RailPainter extends CustomPainter {
  const _RailPainter({required this.fill, required this.rule});
  final Color fill;
  final Color rule;
  @override
  void paint(Canvas canvas, Size size) {
    final cut = 12.0;
    final path = Path()
      ..moveTo(cut, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - cut)
      ..lineTo(size.width - cut, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, cut)
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = rule
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _RailPainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.rule != rule;
}
