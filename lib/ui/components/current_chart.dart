import 'dart:math';

import 'package:flutter/material.dart';

import '../foundation/current_colors.dart';
import '../format/money_format.dart';

/// Chart primitives for money.
///
/// Two rules shape everything here.
///
/// Category is not encoded in colour. A breakdown answers "how large", which
/// bar length already carries; painting each row a different hue would add a
/// second encoding of nothing. The palette also fails a categorical check —
/// moss and river sit 7.2 ΔE apart in normal vision — so hue would be a weak
/// signal even if it carried meaning.
///
/// Direction is never colour alone. Money in and money out are drawn from the
/// income and expense hues, which are only 3.0 ΔE apart under protanopia, so
/// every direction also carries a sign and an arrow.
abstract final class CurrentChart {
  /// Rounded end cap for a data mark.
  static const BorderRadius barRadius = BorderRadius.all(Radius.circular(4));

  /// Shortest visible bar, so a small non-zero value never reads as absent.
  static const double minimumBarFactor = .035;
}

/// Signed change against a previous period.
///
/// Carries an arrow and an explicit sign so the meaning survives without
/// colour vision, in print, and under forced-colours modes.
class DeltaChip extends StatelessWidget {
  const DeltaChip({
    super.key,
    required this.fraction,
    this.spendingContext = true,
  });

  /// Change as a fraction: 0.12 renders as +12%.
  final double fraction;

  /// When true, an increase is spending more and reads as adverse. Set false
  /// for income, where an increase is favourable.
  final bool spendingContext;

  @override
  Widget build(BuildContext context) {
    final rising = fraction >= 0;
    final adverse = spendingContext ? rising : !rising;
    final color = adverse ? context.current.expense : context.current.income;
    final percent = (fraction.abs() * 100).round();
    return Semantics(
      label:
          '${rising ? 'up' : 'down'} $percent percent versus the previous '
          'period',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: context.current.subtle,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              rising
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 13,
              color: color,
            ),
            const SizedBox(width: 3),
            Text(
              '${rising ? '+' : '−'}$percent%',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A labelled row whose bar length encodes magnitude.
class MagnitudeRow extends StatelessWidget {
  const MagnitudeRow({
    super.key,
    required this.label,
    required this.amountMinor,
    required this.currency,
    required this.maximumMinor,
    this.share,
    this.emphasis = false,
  });

  final String label;
  final int amountMinor;
  final String currency;
  final int maximumMinor;

  /// Portion of the whole, 0..1. Shown as a percentage when supplied.
  final double? share;

  /// Draws the bar in the intelligence hue rather than the recessive rule
  /// colour. Reserved for the row the answer is actually about.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final factor = maximumMinor <= 0
        ? CurrentChart.minimumBarFactor
        : max(CurrentChart.minimumBarFactor, amountMinor / maximumMinor);
    final percent = share == null ? null : (share! * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              if (percent != null) ...[
                Text(
                  '$percent%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.current.muted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Text(
                formatMoney(amountMinor, currency),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'Space Grotesk',
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          // Track then fill, so every row shares a baseline the eye can use
          // to compare lengths.
          Stack(
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: context.current.subtle,
                  borderRadius: CurrentChart.barRadius,
                ),
              ),
              FractionallySizedBox(
                widthFactor: factor.clamp(0.0, 1.0),
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: emphasis
                        ? context.current.intelligence
                        : context.current.muted,
                    borderRadius: CurrentChart.barRadius,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Two periods drawn on one shared scale.
///
/// Deliberately a single measure on a single axis: two y-scales would let the
/// bars imply a relationship the numbers do not support.
class ComparisonBars extends StatelessWidget {
  const ComparisonBars({
    super.key,
    required this.currentLabel,
    required this.currentMinor,
    required this.previousLabel,
    required this.previousMinor,
    required this.currency,
    this.spendingContext = true,
  });

  final String currentLabel;
  final int currentMinor;
  final String previousLabel;
  final int previousMinor;
  final String currency;
  final bool spendingContext;

  @override
  Widget build(BuildContext context) {
    final maximum = max(max(currentMinor, previousMinor), 1);
    final fraction = previousMinor == 0
        ? null
        : (currentMinor - previousMinor) / previousMinor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (fraction != null) ...[
          DeltaChip(fraction: fraction, spendingContext: spendingContext),
          const SizedBox(height: 14),
        ],
        MagnitudeRow(
          label: currentLabel,
          amountMinor: currentMinor,
          currency: currency,
          maximumMinor: maximum,
          emphasis: true,
        ),
        MagnitudeRow(
          label: previousLabel,
          amountMinor: previousMinor,
          currency: currency,
          maximumMinor: maximum,
        ),
      ],
    );
  }
}

/// Headline figure. Used when the answer is one number, where a chart would
/// only decorate it.
class HeroAmount extends StatelessWidget {
  const HeroAmount({
    super.key,
    required this.label,
    required this.amountMinor,
    required this.currency,
    this.deltaFraction,
    this.spendingContext = true,
    this.hidden = false,
  });

  final String label;
  final int amountMinor;
  final String currency;
  final double? deltaFraction;
  final bool spendingContext;
  final bool hidden;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.current.muted),
      ),
      const SizedBox(height: 6),
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              hidden ? '••••••' : formatMoney(amountMinor, currency),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (deltaFraction != null && !hidden) ...[
            const SizedBox(width: 10),
            DeltaChip(
              fraction: deltaFraction!,
              spendingContext: spendingContext,
            ),
          ],
        ],
      ),
    ],
  );
}
