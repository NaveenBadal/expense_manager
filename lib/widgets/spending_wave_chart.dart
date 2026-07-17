import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../theme/app_tokens.dart';
import '../theme/app_theme.dart';
import '../utils/currency_utils.dart';

class SpendingWaveChart extends StatefulWidget {
  const SpendingWaveChart({
    super.key,
    required this.expenses,
    required this.currency,
  });

  final List<Expense> expenses;
  final String currency;

  @override
  State<SpendingWaveChart> createState() => _SpendingWaveChartState();
}

class _SpendingWaveChartState extends State<SpendingWaveChart> with SingleTickerProviderStateMixin {
  int? _hoverIndex;
  Offset? _hoverPos;
  late final AnimationController _animController;
  late final Animation<double> _chartAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _chartAnim = CurvedAnimation(
      parent: _animController,
      curve: AppMotion.emphasizedDecelerate,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    
    // 1. Prepare data for the last 7 days of activity
    final dailyAmounts = List<double>.filled(7, 0.0);
    final dayLabels = List<DateTime>.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
    
    for (final exp in widget.expenses) {
      if (exp.isIncome) continue;
      final diff = now.difference(exp.date).inDays;
      if (diff >= 0 && diff < 7) {
        dailyAmounts[6 - diff] += exp.amount;
      }
    }

    final maxAmount = dailyAmounts.reduce(math.max);
    final peak = maxAmount == 0 ? 100.0 : maxAmount * 1.15;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 72,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              
              return GestureDetector(
                onPanUpdate: (details) {
                  final renderBox = context.findRenderObject() as RenderBox;
                  final localPos = renderBox.globalToLocal(details.globalPosition);
                  final colWidth = w / 6;
                  final index = (localPos.dx / colWidth).round().clamp(0, 6);
                  if (_hoverIndex != index) {
                    HapticFeedback.selectionClick();
                  }
                  setState(() {
                    _hoverIndex = index;
                    _hoverPos = Offset(index * colWidth, h - (dailyAmounts[index] / peak) * h);
                  });
                },
                onPanEnd: (_) => setState(() {
                  _hoverIndex = null;
                  _hoverPos = null;
                }),
                onPanDown: (details) {
                  final renderBox = context.findRenderObject() as RenderBox;
                  final localPos = renderBox.globalToLocal(details.globalPosition);
                  final colWidth = w / 6;
                  final index = (localPos.dx / colWidth).round().clamp(0, 6);
                  HapticFeedback.selectionClick();
                  setState(() {
                    _hoverIndex = index;
                    _hoverPos = Offset(index * colWidth, h - (dailyAmounts[index] / peak) * h);
                  });
                },
                onTapDown: (details) {
                  final renderBox = context.findRenderObject() as RenderBox;
                  final localPos = renderBox.globalToLocal(details.globalPosition);
                  final colWidth = w / 6;
                  final index = (localPos.dx / colWidth).round().clamp(0, 6);
                  HapticFeedback.selectionClick();
                  setState(() {
                    _hoverIndex = index;
                    _hoverPos = Offset(index * colWidth, h - (dailyAmounts[index] / peak) * h);
                  });
                },
                onTapUp: (_) => setState(() {
                  _hoverIndex = null;
                  _hoverPos = null;
                }),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedBuilder(
                      animation: _chartAnim,
                      builder: (context, child) {
                        return CustomPaint(
                          size: Size(w, h),
                          painter: _WavePainter(
                            amounts: dailyAmounts,
                            peak: peak,
                            progress: _chartAnim.value,
                            primaryColor: scheme.onPrimaryContainer,
                            accentColor: scheme.onPrimaryContainer.withValues(alpha: 0.15),
                          ),
                        );
                      },
                    ),
                    if (_hoverIndex != null && _hoverPos != null) ...[
                      Positioned(
                        left: _hoverPos!.dx - 4,
                        top: _hoverPos!.dy - 4,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: scheme.onPrimaryContainer,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: scheme.onPrimaryContainer.withValues(alpha: 0.5),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: math.min(math.max(_hoverPos!.dx - 54, 4.0), w - 112),
                        top: -38,
                        child: GlassmorphicContainer(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          borderRadius: BorderRadius.circular(12),
                          color: scheme.onPrimaryContainer.withValues(alpha: 0.1),
                          child: Text(
                            formatAmount(dailyAmounts[_hoverIndex!], widget.currency),
                            style: AppTheme.money(
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: scheme.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: dayLabels.map((date) {
            final isToday = date.day == now.day;
            return Text(
              DateFormat('E').format(date).toUpperCase().substring(0, 1),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isToday
                    ? scheme.onPrimaryContainer
                    : scheme.onPrimaryContainer.withValues(alpha: .5),
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                fontSize: 9.5,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.amounts,
    required this.peak,
    required this.progress,
    required this.primaryColor,
    required this.accentColor,
  });

  final List<double> amounts;
  final double peak;
  final double progress;
  final Color primaryColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final int count = amounts.length;
    if (count < 2) return;

    final double stepX = w / (count - 1);
    final points = <Offset>[];
    for (int i = 0; i < count; i++) {
      final targetY = h - (amounts[i] / peak) * h;
      final y = h - (h - targetY) * progress;
      points.add(Offset(i * stepX, y.clamp(0.0, h)));
    }

    // Smooth Bézier curve path creation
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    final fillPath = Path()..moveTo(points[0].dx, h)..lineTo(points[0].dx, points[0].dy);

    for (int i = 0; i < count - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlX1 = p0.dx + stepX / 2;
      final controlY1 = p0.dy;
      final controlX2 = p1.dx - stepX / 2;
      final controlY2 = p1.dy;

      path.cubicTo(controlX1, controlY1, controlX2, controlY2, p1.dx, p1.dy);
      fillPath.cubicTo(controlX1, controlY1, controlX2, controlY2, p1.dx, p1.dy);
    }
    
    fillPath.lineTo(points.last.dx, h);
    fillPath.close();

    // Draw the gradient beneath the path
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [accentColor, accentColor.withValues(alpha: 0.0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Draw the glowing top curve line
    final linePaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.amounts != amounts || oldDelegate.peak != peak || oldDelegate.progress != progress;
}
