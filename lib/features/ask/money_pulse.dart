import 'package:flutter/material.dart';

import '../../domain/transaction.dart';
import '../../ui/components/current_chart.dart';
import '../../ui/foundation/current_colors.dart';
import '../../ui/format/money_format.dart';

/// Standing summary above the conversation.
///
/// Chat answers a question that was asked; this answers the one nobody
/// bothers to type. Opening the app should state where the month stands
/// without costing a round trip to a model, so it is computed locally from
/// records already on the device.
///
/// It stays deliberately thin. Anything larger competes with the answer
/// below it, and the conversation is what this screen is for.
class MoneyPulse extends StatelessWidget {
  const MoneyPulse({
    super.key,
    required this.transactions,
    required this.hideAmounts,
    this.onTap,
  });

  final List<MoneyTransaction> transactions;
  final bool hideAmounts;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final summary = _summarise(transactions, now);
    if (summary == null) return const SizedBox.shrink();

    return Semantics(
      button: onTap != null,
      label:
          'Spent ${formatMoney(summary.spentMinor, summary.currency)} '
          'this month. Open activity.',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spent this month',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.current.muted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            hideAmounts
                                ? '••••••'
                                : formatMoney(
                                    summary.spentMinor,
                                    summary.currency,
                                  ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                        ),
                        if (summary.changeFraction != null && !hideAmounts) ...[
                          const SizedBox(width: 9),
                          DeltaChip(fraction: summary.changeFraction!),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Hidden alongside the figure: the shape of the month leaks the
              // trend the person asked to keep covered.
              if (!hideAmounts && summary.daily.length > 1) ...[
                const SizedBox(width: 16),
                SizedBox(width: 96, child: Sparkline(values: summary.daily)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Totals the current calendar month against the previous one.
  ///
  /// Uses only the single most common currency: mixing rates into one figure
  /// would state a number the records do not support.
  static _PulseSummary? _summarise(
    List<MoneyTransaction> values,
    DateTime now,
  ) {
    final outgoing = values.where(
      (item) => item.direction == TransactionDirection.outgoing,
    );
    if (outgoing.isEmpty) return null;

    final counts = <String, int>{};
    for (final item in outgoing) {
      counts[item.currency] = (counts[item.currency] ?? 0) + 1;
    }
    final currency = counts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;

    final monthStart = DateTime(now.year, now.month);
    final previousStart = DateTime(now.year, now.month - 1);
    var spent = 0;
    var previous = 0;
    final daily = List<int>.filled(now.day, 0);
    for (final item in outgoing.where((e) => e.currency == currency)) {
      final at = item.occurredAt;
      if (!at.isBefore(monthStart)) {
        spent += item.amountMinor;
        final index = at.day - 1;
        if (index >= 0 && index < daily.length) {
          daily[index] += item.amountMinor;
        }
      } else if (!at.isBefore(previousStart) && at.isBefore(monthStart)) {
        previous += item.amountMinor;
      }
    }
    if (spent == 0) return null;

    return _PulseSummary(
      spentMinor: spent,
      currency: currency,
      // Only meaningful with a prior month to compare against.
      changeFraction: previous == 0 ? null : (spent - previous) / previous,
      daily: daily,
    );
  }
}

class _PulseSummary {
  const _PulseSummary({
    required this.spentMinor,
    required this.currency,
    required this.changeFraction,
    required this.daily,
  });
  final int spentMinor;
  final String currency;
  final double? changeFraction;
  final List<int> daily;
}
