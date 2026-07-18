import 'package:flutter/material.dart';

/// Compatibility tokens for layout, brief transition motion, and financial
/// semantics. Visual identity lives in `flow_os`; no shape or component roles
/// belong here.
class AppSpacing {
  const AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double page = 20;
  static const double section = 24;
  static const double region = 32;
  static const double narrative = 48;
}

class AppBreakpoint {
  const AppBreakpoint._();
  static const double compact = 600;
  static const double rail = 840;
  static const double extendedRail = 1100;
  static const double contentMax = 720;
}

/// Only short, event-driven transitions. Flow schedules no repeating or idle
/// animation frames.
class AppMotion {
  const AppMotion._();
  static const Duration fast = Duration(milliseconds: 220);
  static const Duration medium = Duration(milliseconds: 360);
  static const Duration slow = Duration(milliseconds: 520);
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);
  static const Curve standard = Curves.easeOutCubic;
  static const SpringDescription spring = SpringDescription(
    mass: 1,
    stiffness: 520,
    damping: 34,
  );
}

@immutable
class FinanceColors extends ThemeExtension<FinanceColors> {
  const FinanceColors({
    required this.income,
    required this.incomeSurface,
    required this.expense,
    required this.expenseSurface,
    required this.warning,
    required this.warningSurface,
  });
  final Color income,
      incomeSurface,
      expense,
      expenseSurface,
      warning,
      warningSurface;
  static const light = FinanceColors(
    income: Color(0xFF117867),
    incomeSurface: Color(0xFFD5F2E9),
    expense: Color(0xFFC0344B),
    expenseSurface: Color(0xFFFCE0E4),
    warning: Color(0xFF9A5B00),
    warningSurface: Color(0xFFFBEAD0),
  );
  static const dark = FinanceColors(
    income: Color(0xFF6FD8C2),
    incomeSurface: Color(0xFF0C3A31),
    expense: Color(0xFFFF9FAF),
    expenseSurface: Color(0xFF48222B),
    warning: Color(0xFFF7C46B),
    warningSurface: Color(0xFF3B2C0A),
  );
  @override
  FinanceColors copyWith({
    Color? income,
    Color? incomeSurface,
    Color? expense,
    Color? expenseSurface,
    Color? warning,
    Color? warningSurface,
  }) => FinanceColors(
    income: income ?? this.income,
    incomeSurface: incomeSurface ?? this.incomeSurface,
    expense: expense ?? this.expense,
    expenseSurface: expenseSurface ?? this.expenseSurface,
    warning: warning ?? this.warning,
    warningSurface: warningSurface ?? this.warningSurface,
  );
  @override
  FinanceColors lerp(ThemeExtension<FinanceColors>? other, double t) {
    if (other is! FinanceColors) return this;
    return FinanceColors(
      income: Color.lerp(income, other.income, t)!,
      incomeSurface: Color.lerp(incomeSurface, other.incomeSurface, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      expenseSurface: Color.lerp(expenseSurface, other.expenseSurface, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSurface: Color.lerp(warningSurface, other.warningSurface, t)!,
    );
  }
}

extension FinanceColorsX on BuildContext {
  FinanceColors get finance =>
      Theme.of(this).extension<FinanceColors>() ?? FinanceColors.light;
}
