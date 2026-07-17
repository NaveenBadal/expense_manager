import 'package:flutter/material.dart';

/// Design tokens — the single source of truth for spacing, shape, motion,
/// and elevation across the app. Keeps every screen visually consistent.
///
/// The system follows Material 3 Expressive: generous, characterful shapes
/// applied with *intent* (emphasis, not decoration), springy motion, and a
/// small, deliberate spacing rhythm. Three shape roles only — [ExpressiveShape.hero]
/// for feature surfaces, [ExpressiveShape.card] for content, and pills for
/// controls — so the whole app reads as one calm, confident system.
class AppRadius {
  const AppRadius._();
  static const double xs = 10;
  static const double sm = 14;
  static const double md = 18;
  static const double lg = 22;
  static const double xl = 28;
  static const double xxl = 36;
  static const double pill = 999;

  static BorderRadius all(double r) => BorderRadius.circular(r);
}

/// Consistent spacing rhythm (4pt base). Use these instead of magic numbers so
/// vertical and horizontal cadence stays even across every screen.
class AppSpacing {
  const AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double page = 20;
}

/// Motion tokens tuned for Material 3 Expressive. Springy, confident easing on
/// spatial changes; snappier standard easing on fades and color.
class AppMotion {
  const AppMotion._();

  static const Duration fast = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 340);
  static const Duration slow = Duration(milliseconds: 500);

  /// Expressive emphasized easing — overshoots subtly, feels alive.
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);
  static const Curve standard = Curves.easeOutCubic;

  /// Spatial spring for interactive surfaces (press, reveal, reorder).
  static const SpringDescription spring = SpringDescription(
    mass: 1,
    stiffness: 520,
    damping: 34,
  );
}

/// The three shape roles of the app. Expressive character comes from
/// *consistency of intent*, not from randomising corners per item.
class ExpressiveShape {
  const ExpressiveShape._();

  /// Content role — every list card, tile, and settings surface. One calm,
  /// generous continuous radius so scrolling lists feel like a single rhythm.
  static OutlinedBorder card({
    Color color = Colors.transparent,
    double? radius,
  }) => ContinuousRectangleBorder(
    borderRadius: BorderRadius.circular(radius ?? 30),
    side: color == Colors.transparent
        ? BorderSide.none
        : BorderSide(color: color),
  );

  /// Control role — buttons, chips, FABs. Near-pill continuous shape.
  static OutlinedBorder soft({Color color = Colors.transparent}) =>
      ContinuousRectangleBorder(
        borderRadius: BorderRadius.circular(40),
        side: color == Colors.transparent
            ? BorderSide.none
            : BorderSide(color: color),
      );

  /// Emphasis role — hero/feature surfaces only (monthly summary, detail
  /// header, onboarding art). The signature asymmetric expressive silhouette.
  static OutlinedBorder hero({Color color = Colors.transparent}) =>
      ContinuousRectangleBorder(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(64),
          bottomLeft: Radius.circular(64),
          bottomRight: Radius.circular(36),
        ),
        side: color == Colors.transparent
            ? BorderSide.none
            : BorderSide(color: color),
      );

  /// Content radius for lists. Kept as a single, consistent expressive value —
  /// no per-index jitter. The [index] parameter is retained for call-site
  /// compatibility but intentionally ignored so lists read as one calm rhythm.
  static BorderRadius playful(int index) => BorderRadius.circular(30);

  static OutlinedBorder playfulBorder(int index, {Color? color}) =>
      ContinuousRectangleBorder(
        borderRadius: BorderRadius.circular(30),
        side: color == null ? BorderSide.none : BorderSide(color: color),
      );
}

/// Semantic finance colors resolved per theme brightness.
/// Tuned to sit inside the app's expressive purple scheme — the income green
/// leans teal-forward and the expense red carries a warm rose, so they read as
/// part of the same tonal family rather than stock traffic-light colors.
/// Registered as a [ThemeExtension] so any widget can read them via
/// `Theme.of(context).extension<FinanceColors>()!`.
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

  final Color income;
  final Color incomeSurface;
  final Color expense;
  final Color expenseSurface;
  final Color warning;
  final Color warningSurface;

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
  }) {
    return FinanceColors(
      income: income ?? this.income,
      incomeSurface: incomeSurface ?? this.incomeSurface,
      expense: expense ?? this.expense,
      expenseSurface: expenseSurface ?? this.expenseSurface,
      warning: warning ?? this.warning,
      warningSurface: warningSurface ?? this.warningSurface,
    );
  }

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

/// Convenience accessor so widgets can write `context.finance.income`.
extension FinanceColorsX on BuildContext {
  FinanceColors get finance =>
      Theme.of(this).extension<FinanceColors>() ?? FinanceColors.light;
}
