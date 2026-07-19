import 'package:flutter_test/flutter_test.dart';
import 'package:fund_flow/ui/format/money_format.dart';

void main() {
  test('rupees render with the rupee sign, not the code', () {
    // NumberFormat.currency would print "INR1,85,000" here.
    expect(formatMoney(18500000, 'INR'), startsWith('\u20B9'));
    expect(formatMoney(18500000, 'INR'), isNot(contains('INR')));
  });

  test('rupees use Indian digit grouping', () {
    // 1,85,000 not 185,000 — Western grouping reads wrong in this market.
    expect(formatMoney(18500000, 'INR'), contains('1,85,000'));
  });

  test('whole amounts drop the empty fraction', () {
    expect(formatMoney(250000, 'INR'), isNot(contains('.00')));
  });

  test('fractional amounts keep their paise', () {
    expect(formatMoney(69925, 'INR'), contains('699.25'));
  });

  test('currencies without minor units never show a fraction', () {
    expect(formatMoney(1500, 'JPY'), isNot(contains('.')));
  });

  test('hidden amounts reveal nothing', () {
    expect(formatMoney(18500000, 'INR', hidden: true), '••••');
  });
}
