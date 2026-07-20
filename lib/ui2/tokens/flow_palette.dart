import 'package:flutter/material.dart';

/// Colour tokens.
///
/// The categorical slots were computed and validated rather than chosen by
/// eye. The previous palette failed on colour-vision separation — its expense
/// and income hues sat 3.0 ΔE apart under protanopia, which is the classic
/// red-green failure applied to the direction money moved — so category could
/// not be encoded in colour at all.
///
/// These slots pass every check in both modes:
///
///   light  CVD ΔE 15.2 · normal ΔE 20.3 · all ≥ 3:1 against the surface
///   dark   CVD ΔE  9.2 · normal ΔE 16.3 · all ≥ 3:1 against the surface
///
/// Dark is selected against the dark surface rather than flipped from light,
/// because a flipped ramp lands outside the band the dark surface requires.
///
/// Adjacent slots alternate lightness on purpose. Deuteranopia collapses hue
/// difference, so value difference is what survives it; spacing hues alone
/// cannot get six slots past the check at a single lightness.
abstract final class FlowPalette {
  // ---------------------------------------------------------------- surfaces
  // Warm rather than neutral. A paper ground is the one thing worth keeping
  // from the previous language: every other money app is stark white or
  // black, and this is a screen someone opens daily.
  // Canvas, sunken and raised used to sit within a few percent of each
  // other, so a card could not separate from the page by tone and — with no
  // shadow anywhere either — could not separate at all. The ground is now a
  // touch deeper and raised surfaces go to near-white, which is what lets a
  // card read as a card.
  static const lightCanvas = Color(0xFFF1EEE8);
  static const lightSunken = Color(0xFFE8E5DD);
  static const lightRaised = Color(0xFFFFFEFC);
  static const lightLine = Color(0xFFDCD8CF);

  static const darkCanvas = Color(0xFF121316);
  static const darkSunken = Color(0xFF0C0D10);
  static const darkRaised = Color(0xFF1E2126);
  static const darkLine = Color(0xFF32353C);

  // -------------------------------------------------------------------- ink
  static const lightInk = Color(0xFF1A1C1B);
  static const lightInkSoft = Color(0xFF5C605E);
  static const lightInkFaint = Color(0xFF8A8E8B);

  static const darkInk = Color(0xFFF2F1EC);
  static const darkInkSoft = Color(0xFFAFB2AE);
  static const darkInkFaint = Color(0xFF7B7F7C);

  // ------------------------------------------------------------ categorical
  /// Fixed order. A ninth series is never a generated hue: it folds into
  /// "Other" or the chart becomes small multiples.
  static const lightSeries = <Color>[
    Color(0xFF005496),
    Color(0xFF539344),
    Color(0xFF8C3019),
    Color(0xFF997E00),
    Color(0xFF5F3D8E),
    Color(0xFF009891),
  ];

  static const darkSeries = <Color>[
    Color(0xFF2D78BD),
    Color(0xFF65A556),
    Color(0xFFB3543C),
    Color(0xFFAB9017),
    Color(0xFF8160B5),
    Color(0xFF00ABA4),
  ];

  // --------------------------------------------------------------- semantic
  // Direction reuses the validated green and red slots, which sit 15.2 ΔE
  // apart under deuteranopia. Even so, direction always carries a sign or an
  // arrow: colour is reinforcement here, never the only signal.
  static const lightIncome = Color(0xFF539344);
  static const lightExpense = Color(0xFF8C3019);
  static const lightAttention = Color(0xFF997E00);
  static const lightAccent = Color(0xFF005496);

  static const darkIncome = Color(0xFF65A556);
  static const darkExpense = Color(0xFFB3543C);
  static const darkAttention = Color(0xFFAB9017);
  static const darkAccent = Color(0xFF2D78BD);
}

/// Resolved colours for the active brightness.
@immutable
class FlowColors extends ThemeExtension<FlowColors> {
  const FlowColors({
    required this.canvas,
    required this.sunken,
    required this.raised,
    required this.line,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.series,
    required this.income,
    required this.expense,
    required this.attention,
    required this.accent,
    required this.onAccent,
  });

  /// Three levels so hierarchy exists without shadows: [sunken] recedes,
  /// [canvas] is the page, [raised] advances.
  final Color canvas;
  final Color sunken;
  final Color raised;
  final Color line;

  final Color ink;
  final Color inkSoft;
  final Color inkFaint;

  final List<Color> series;
  final Color income;
  final Color expense;
  final Color attention;
  final Color accent;
  final Color onAccent;

  /// Slot for series [index], folding anything past the defined slots back
  /// into the fixed order rather than generating a new hue.
  Color seriesAt(int index) => series[index % series.length];

  static const light = FlowColors(
    canvas: FlowPalette.lightCanvas,
    sunken: FlowPalette.lightSunken,
    raised: FlowPalette.lightRaised,
    line: FlowPalette.lightLine,
    ink: FlowPalette.lightInk,
    inkSoft: FlowPalette.lightInkSoft,
    inkFaint: FlowPalette.lightInkFaint,
    series: FlowPalette.lightSeries,
    income: FlowPalette.lightIncome,
    expense: FlowPalette.lightExpense,
    attention: FlowPalette.lightAttention,
    accent: FlowPalette.lightAccent,
    onAccent: Colors.white,
  );

  static const dark = FlowColors(
    canvas: FlowPalette.darkCanvas,
    sunken: FlowPalette.darkSunken,
    raised: FlowPalette.darkRaised,
    line: FlowPalette.darkLine,
    ink: FlowPalette.darkInk,
    inkSoft: FlowPalette.darkInkSoft,
    inkFaint: FlowPalette.darkInkFaint,
    series: FlowPalette.darkSeries,
    income: FlowPalette.darkIncome,
    expense: FlowPalette.darkExpense,
    attention: FlowPalette.darkAttention,
    accent: FlowPalette.darkAccent,
    onAccent: Colors.white,
  );

  @override
  FlowColors copyWith({
    Color? canvas,
    Color? sunken,
    Color? raised,
    Color? line,
    Color? ink,
    Color? inkSoft,
    Color? inkFaint,
    List<Color>? series,
    Color? income,
    Color? expense,
    Color? attention,
    Color? accent,
    Color? onAccent,
  }) => FlowColors(
    canvas: canvas ?? this.canvas,
    sunken: sunken ?? this.sunken,
    raised: raised ?? this.raised,
    line: line ?? this.line,
    ink: ink ?? this.ink,
    inkSoft: inkSoft ?? this.inkSoft,
    inkFaint: inkFaint ?? this.inkFaint,
    series: series ?? this.series,
    income: income ?? this.income,
    expense: expense ?? this.expense,
    attention: attention ?? this.attention,
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
  );

  /// Themes swap wholesale rather than interpolating: a half-blended palette
  /// is not a state any of these values were validated in.
  @override
  FlowColors lerp(covariant FlowColors? other, double t) =>
      t < .5 ? this : (other ?? this);
}

extension FlowColorsOf on BuildContext {
  FlowColors get flow => Theme.of(this).extension<FlowColors>()!;
}
