import '../models/expense.dart';

/// Deterministic last-mile guard for AI imports.
///
/// Banks often describe one payment twice (for example, a UPI alert followed
/// by an account debit alert). The wording is different, so raw SMS equality
/// is insufficient. This detector combines amount, time, direction, merchant
/// and transaction-reference evidence and only suppresses high-confidence
/// matches.
class TransactionDuplicateDetector {
  const TransactionDuplicateDetector();

  static const Duration candidateWindow = Duration(hours: 6);

  bool isDuplicate(Expense incoming, Expense existing) =>
      confidence(incoming, existing) >= 0.82;

  double confidence(Expense a, Expense b) {
    if (a.currency.toUpperCase() != b.currency.toUpperCase() ||
        a.type != b.type ||
        (a.amount - b.amount).abs() > 0.005) {
      return 0;
    }

    final gap = a.date.difference(b.date).abs();
    if (gap > candidateWindow) return 0;

    var score = 0.52; // exact monetary fingerprint
    if (gap <= const Duration(minutes: 2)) {
      score += 0.27;
    } else if (gap <= const Duration(minutes: 10)) {
      score += 0.18;
    } else if (gap <= const Duration(hours: 1)) {
      score += 0.08;
    }

    final merchantA = _tokens(a.normalizedMerchant ?? a.merchant);
    final merchantB = _tokens(b.normalizedMerchant ?? b.merchant);
    if (merchantA.isNotEmpty && merchantB.isNotEmpty) {
      final overlap =
          merchantA.intersection(merchantB).length /
          merchantA.union(merchantB).length;
      if (overlap >= .5) score += .22;
    }

    final refsA = _references(a.originalSms);
    final refsB = _references(b.originalSms);
    if (refsA.intersection(refsB).isNotEmpty) score += .35;

    if (_normalizedSms(a.originalSms) == _normalizedSms(b.originalSms)) {
      score += .4;
    }
    return score.clamp(0, 1);
  }

  Set<String> _tokens(String input) => input
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .split(RegExp(r'\s+'))
      .where((word) => word.length > 2 && !_noise.contains(word))
      .toSet();

  Set<String> _references(String input) =>
      RegExp(r'\b[a-z0-9]{8,22}\b', caseSensitive: false)
          .allMatches(input)
          .map((match) => match.group(0)!.toLowerCase())
          .where((value) => value.contains(RegExp(r'\d')))
          .toSet();

  String _normalizedSms(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  static const _noise = {
    'payment',
    'transaction',
    'debit',
    'debited',
    'credit',
    'credited',
    'bank',
    'account',
    'acct',
    'made',
    'using',
    'from',
    'your',
    'towards',
    'limited',
    'india',
    'merchant',
    'purchase',
    'paid',
    'sent',
  };
}
