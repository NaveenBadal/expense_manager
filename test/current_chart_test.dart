import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fund_flow/ui/components/current_chart.dart';
import 'package:fund_flow/ui/foundation/current_theme.dart';

Widget _host(Widget child) => MaterialApp(
  theme: CurrentTheme.light(),
  home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
);

void main() {
  group('DeltaChip', () {
    testWidgets('states direction in text and icon, not colour alone', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const DeltaChip(fraction: .12)));
      // The sign carries the meaning for readers who cannot separate the
      // income and expense hues, which sit 3.0 delta-E apart under protanopia.
      expect(find.text('+12%'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    });

    testWidgets('renders a fall with an explicit minus and down arrow', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const DeltaChip(fraction: -.08)));
      expect(find.text('−8%'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
    });

    testWidgets('describes the change for screen readers', (tester) async {
      await tester.pumpWidget(_host(const DeltaChip(fraction: .2)));
      expect(
        find.bySemanticsLabel('up 20 percent versus the previous period'),
        findsOneWidget,
      );
    });
  });

  group('MagnitudeRow', () {
    testWidgets('shows label, share and formatted amount', (tester) async {
      await tester.pumpWidget(
        _host(
          const MagnitudeRow(
            label: 'Food',
            amountMinor: 1240000,
            currency: 'INR',
            maximumMinor: 2480000,
            share: .5,
          ),
        ),
      );
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('keeps a zero row visible rather than collapsing it', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const MagnitudeRow(
            label: 'Empty',
            amountMinor: 0,
            currency: 'INR',
            maximumMinor: 100000,
          ),
        ),
      );
      final sized = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      // A non-zero floor means a small value never reads as missing data.
      expect(sized.widthFactor, CurrentChart.minimumBarFactor);
    });
  });

  group('ComparisonBars', () {
    testWidgets('draws both periods on one shared scale', (tester) async {
      await tester.pumpWidget(
        _host(
          const ComparisonBars(
            currentLabel: 'July',
            currentMinor: 120000,
            previousLabel: 'June',
            previousMinor: 100000,
            currency: 'INR',
          ),
        ),
      );
      expect(find.text('July'), findsOneWidget);
      expect(find.text('June'), findsOneWidget);
      expect(find.text('+20%'), findsOneWidget);

      final bars = tester
          .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
          .toList();
      // One axis: the smaller period is drawn proportionally, never rescaled
      // to fill its own row.
      expect(bars.first.widthFactor, 1.0);
      expect(bars.last.widthFactor, closeTo(100000 / 120000, .0001));
    });

    testWidgets('omits the delta when there is no previous period', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ComparisonBars(
            currentLabel: 'July',
            currentMinor: 120000,
            previousLabel: 'June',
            previousMinor: 0,
            currency: 'INR',
          ),
        ),
      );
      expect(find.byType(DeltaChip), findsNothing);
    });
  });

  group('HeroAmount', () {
    testWidgets('respects hidden amounts', (tester) async {
      await tester.pumpWidget(
        _host(
          const HeroAmount(
            label: 'This month',
            amountMinor: 4218000,
            currency: 'INR',
            hidden: true,
          ),
        ),
      );
      expect(find.text('••••••'), findsOneWidget);
      // A delta would leak the trend even with the figure masked.
      expect(find.byType(DeltaChip), findsNothing);
    });
  });
}
