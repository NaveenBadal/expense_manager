import 'package:flutter/material.dart';

import '../foundation/flow_color.dart';
import '../primitives/coordinate_label.dart';
import '../primitives/loom_mark.dart';

class CommandColumn extends StatelessWidget {
  const CommandColumn({
    super.key,
    required this.selectedIndex,
    required this.extended,
    required this.onSelected,
  });

  final int selectedIndex;
  final bool extended;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: FlowColor.raised(context),
    child: SafeArea(
      child: SizedBox(
        width: extended ? 214 : 86,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 20, 12, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: extended
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  const LoomMark(size: 38),
                  if (extended) ...[
                    const SizedBox(width: 11),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CoordinateLabel('FLOW / OS'),
                          Text(
                            'COMMAND',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 46),
              _ColumnPort(
                selected: selectedIndex == 0,
                extended: extended,
                code: '00',
                label: 'ASK',
                detail: 'Reason with Flow',
                glyph: const LoomMark(size: 28),
                onTap: () => onSelected(0),
              ),
              const SizedBox(height: 9),
              _ColumnPort(
                selected: selectedIndex == 1,
                extended: extended,
                code: '01',
                label: 'PROOF',
                detail: 'Inspect evidence',
                glyph: const _ColumnGlyph(kind: 1),
                onTap: () => onSelected(1),
              ),
              const SizedBox(height: 9),
              _ColumnPort(
                selected: selectedIndex == 2,
                extended: extended,
                code: '02',
                label: 'SYSTEM',
                detail: 'Control the agent',
                glyph: const _ColumnGlyph(kind: 2),
                onTap: () => onSelected(2),
              ),
              const Spacer(),
              if (extended)
                Text(
                  'LOCAL / PRIVATE / PROOF-BOUND',
                  style: TextStyle(
                    color: FlowColor.quiet(context),
                    fontSize: 7,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .7,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ColumnPort extends StatelessWidget {
  const _ColumnPort({
    required this.selected,
    required this.extended,
    required this.code,
    required this.label,
    required this.detail,
    required this.glyph,
    required this.onTap,
  });
  final bool selected;
  final bool extended;
  final String code;
  final String label;
  final String detail;
  final Widget glyph;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '$label, $detail',
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? FlowColor.plane(context) : Colors.transparent,
          border: BorderDirectional(
            start: BorderSide(
              color: selected ? FlowColor.proof : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: extended
              ? MainAxisAlignment.start
              : MainAxisAlignment.center,
          children: [
            glyph,
            if (extended) ...[
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$code / $label',
                      style: TextStyle(
                        color: selected
                            ? FlowColor.proof
                            : FlowColor.content(context),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .7,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      style: TextStyle(
                        color: FlowColor.quiet(context),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _ColumnGlyph extends StatelessWidget {
  const _ColumnGlyph({required this.kind});
  final int kind;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 28,
    height: 28,
    child: CustomPaint(
      painter: _ColumnGlyphPainter(kind: kind, color: FlowColor.quiet(context)),
    ),
  );
}

class _ColumnGlyphPainter extends CustomPainter {
  const _ColumnGlyphPainter({required this.kind, required this.color});
  final int kind;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    if (kind == 1) {
      canvas.drawRect(const Rect.fromLTWH(4, 2, 20, 24), paint);
      for (final y in const [9.0, 15.0, 21.0]) {
        canvas.drawLine(Offset(8, y), Offset(20, y), paint);
      }
      return;
    }
    canvas.drawLine(const Offset(3, 14), const Offset(25, 14), paint);
    canvas.drawLine(const Offset(14, 3), const Offset(14, 25), paint);
    canvas.drawRect(const Rect.fromLTWH(10, 10, 8, 8), paint);
  }

  @override
  bool shouldRepaint(covariant _ColumnGlyphPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}
