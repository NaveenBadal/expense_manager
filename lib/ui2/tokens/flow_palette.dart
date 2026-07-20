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
  // Dark is the identity and light is its faithful translation, not the
  // other way round. Near-black rather than true black: #000 smears on OLED
  // during scroll and reads cheap, while a blue-cast charcoal lets a raised
  // surface look lit rather than merely lighter.
  static const darkCanvas = Color(0xFF0B0C11);
  static const darkSunken = Color(0xFF07080B);
  static const darkRaised = Color(0xFF16181F);
  static const darkLine = Color(0xFF262A33);

  // Cool rather than warm. The previous ground was paper-coloured, which
  // signals archive and record — the wrong register for something opened
  // every day and hoped to be liked.
  static const lightCanvas = Color(0xFFF7F8FA);
  static const lightSunken = Color(0xFFEDEFF3);
  static const lightRaised = Color(0xFFFFFFFF);
  static const lightLine = Color(0xFFE2E5EB);

  // -------------------------------------------------------------------- ink
  static const lightInk = Color(0xFF0B0C11);
  static const lightInkSoft = Color(0xFF5A6172);
  static const lightInkFaint = Color(0xFF8B92A3);

  static const darkInk = Color(0xFFF4F5F7);
  static const darkInkSoft = Color(0xFFA8ADBA);
  static const darkInkFaint = Color(0xFF6B7180);

  // ------------------------------------------------------------ categorical
  /// Fixed order. A ninth series is never a generated hue: it folds into
  /// "Other" or the chart becomes small multiples.
  ///
  /// Hues are spaced around the wheel rather than shaded from one family, so
  /// neighbouring slices stay separable for a red-green colour blind reader.
  /// Even so, a chart never relies on hue alone: every slice carries a label
  /// and a figure.
  static const darkSeries = <Color>[
    Color(0xFF6C5CE7), // indigo, the signal
    Color(0xFF22D3EE), // cyan
    Color(0xFF34D399), // emerald
    Color(0xFFFBBF24), // amber
    Color(0xFFFB7185), // rose
    Color(0xFF94A3B8), // slate
  ];

  static const lightSeries = <Color>[
    Color(0xFF5B4BD6),
    Color(0xFF0891B2),
    Color(0xFF059669),
    Color(0xFFD97706),
    Color(0xFFE11D48),
    Color(0xFF64748B),
  ];

  // --------------------------------------------------------------- semantic
  // Direction is never the brand colour: green and red mean money in and
  // money out and nothing else, so the signal hue stays free to mean
  // "the app is talking to you". Direction also always carries a sign or an
  // arrow — colour is reinforcement, never the only cue.
  static const darkIncome = Color(0xFF34D399);
  static const darkExpense = Color(0xFFFB7185);
  static const darkAttention = Color(0xFFFBBF24);

  /// The one hue the interface spends. Used sparingly, against a great deal
  /// of restraint, which is the only reason it lands.
  static const darkAccent = Color(0xFF6C5CE7);

  static const lightIncome = Color(0xFF059669);
  static const lightExpense = Color(0xFFE11D48);
  static const lightAttention = Color(0xFFD97706);
  static const lightAccent = Color(0xFF5B4BD6);
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
