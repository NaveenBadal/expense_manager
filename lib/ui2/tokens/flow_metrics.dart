import 'package:flutter/widgets.dart';

/// Geometry, spacing and motion.
///
/// The previous language used radii of 16, 18, 20, 26 and 999 with no scale
/// behind them. Large radii on hairline borders read as a friendly consumer
/// app; a ledger reads as more credible when its geometry is tighter, so the
/// scale starts smaller and every value is drawn from it.
abstract final class FlowRadius {
  /// Data marks and small chips.
  static const BorderRadius xs = BorderRadius.all(Radius.circular(4));

  /// Dense rows, inputs, tiles.
  static const BorderRadius sm = BorderRadius.all(Radius.circular(8));

  /// Cards.
  static const BorderRadius md = BorderRadius.all(Radius.circular(12));

  /// Sheets and containers that hold cards.
  static const BorderRadius lg = BorderRadius.all(Radius.circular(16));

  /// Pills, where the shape itself carries the meaning.
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
}

/// A 4pt rhythm. Everything is a multiple, so vertical spacing stacks
/// predictably instead of accumulating one-off values.
abstract final class FlowSpace {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double huge = 48;
}

/// Row heights.
///
/// A ledger is scanned in bulk, so its rows are deliberately tighter than a
/// comfortable reading measure. The previous Activity list showed about five
/// transactions per screen against a ledger of hundreds.
abstract final class FlowDensity {
  /// Ledger rows, browsed by the hundred.
  static const double compactRow = 52;

  /// Settings and one-off rows.
  static const double comfortableRow = 64;

  /// Minimum touch target, honoured even inside compact rows.
  static const double minimumTarget = 44;
}

/// Motion.
///
/// Durations are short and curves decelerate: this is an interface that
/// responds, not one that performs. Anything longer starts to feel like
/// waiting for the interface rather than for an answer.
abstract final class FlowMotion {
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration quick = Duration(milliseconds: 160);
  static const Duration standard = Duration(milliseconds: 240);
  static const Duration deliberate = Duration(milliseconds: 360);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve move = Curves.easeInOutCubic;

  /// Gap between staggered items, small enough that a list of eight still
  /// settles inside a beat.
  static const Duration stagger = Duration(milliseconds: 40);

  /// Honours the platform reduced-motion setting. Animation carries meaning
  /// here, so it collapses to instant rather than being skipped outright.
  static Duration respecting(BuildContext context, Duration duration) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false
      ? Duration.zero
      : duration;
}
