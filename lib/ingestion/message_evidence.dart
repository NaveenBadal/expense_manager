/// Deterministic checks that run against the raw message body after the
/// model answers.
///
/// The model is trusted to read meaning; it is not trusted to invent numbers.
/// A hallucinated `amountMinor` writes a plausible-looking but wrong figure
/// into the ledger and silently corrupts every total that follows, so every
/// extracted amount must be traceable to a literal number in the source text.
library;

/// Currencies whose smallest unit is not 1/100 of the major unit. Anything
/// absent from this map is treated as two decimal places.
const Map<String, int> _minorUnitDigits = {
  'JPY': 0,
  'KRW': 0,
  'VND': 0,
  'CLP': 0,
  'ISK': 0,
  'BHD': 3,
  'KWD': 3,
  'OMR': 3,
  'JOD': 3,
  'TND': 3,
};

int minorUnitDigitsFor(String currency) =>
    _minorUnitDigits[currency.toUpperCase()] ?? 2;

/// A number literal found in the message, with the surrounding words that
/// give it meaning.
class AmountLiteral {
  const AmountLiteral({
    required this.minorUnits,
    required this.raw,
    required this.context,
  });

  final int minorUnits;
  final String raw;

  /// Lower-cased text immediately preceding the literal, used to tell a
  /// transaction amount apart from a balance or limit.
  final String context;

  static final _balanceWords = RegExp(
    r'\b(avl|avbl|available|closing|opening|current|total|outstanding|'
    r'a\/c|acct|account)?\s*(bal|balance|limit|due|emi due|min amt|'
    r'minimum|reward|points|cashback earned)\b',
    caseSensitive: false,
  );

  /// True when the words before the number describe a standing figure rather
  /// than money that moved.
  bool get looksLikeBalance => _balanceWords.hasMatch(context);
}

/// Every number in [body] that could plausibly be a money amount, converted
/// to minor units for [currency].
///
/// Deliberately permissive: this backs a "did the model make this up" check,
/// so over-collecting is safe and under-collecting causes false rejections.
List<AmountLiteral> amountLiteralsIn(String body, String currency) {
  final digits = minorUnitDigitsFor(currency);
  final pattern = RegExp(
    // Optional currency marker, optional Dr./Cr., then the number. Banks
    // write "INR Dr. 543.10", "Rs.2,870", "₹1234.50" and bare "250.00".
    r'(?:(?:rs|inr|₹|usd|\$|eur|€|gbp|£|aed|sgd)\s*\.?\s*)?'
    r'(?:(?:dr|cr)\.?\s*)?'
    r'(\d{1,3}(?:,\d{2,3})+(?:\.\d{1,3})?|\d+(?:\.\d{1,3})?)',
    caseSensitive: false,
  );
  final values = <AmountLiteral>[];
  for (final match in pattern.allMatches(body)) {
    final raw = match.group(1);
    if (raw == null) continue;
    final normalized = raw.replaceAll(',', '');
    final parsed = double.tryParse(normalized);
    if (parsed == null || parsed <= 0) continue;

    // A bare integer with no decimal part and no currency marker is usually a
    // reference number, card suffix or date fragment rather than an amount,
    // but it is still collected: rejecting it here would cause the validator
    // to reject legitimate "spent Rs 500" style extractions.
    final scaled = (parsed * _pow10(digits)).round();
    if (scaled <= 0) continue;

    final start = match.start < 40 ? 0 : match.start - 40;
    values.add(
      AmountLiteral(
        minorUnits: scaled,
        raw: raw,
        context: body.substring(start, match.start).toLowerCase(),
      ),
    );
  }
  return values;
}

int _pow10(int exponent) {
  var value = 1;
  for (var i = 0; i < exponent; i++) {
    value *= 10;
  }
  return value;
}

/// Why a model-extracted transaction was rejected by the deterministic pass.
enum EvidenceFailure {
  /// The amount does not correspond to any number in the message body.
  amountNotInMessage,

  /// The amount only matches a figure labelled as a balance, limit or due
  /// total, which is a standing value rather than money that moved.
  amountIsBalance,

  /// The message authorises a future payment rather than reporting a
  /// completed one, so counting it would double-count the real debit.
  authorizationOnly,
}

extension EvidenceFailureMessage on EvidenceFailure {
  String get message => switch (this) {
    EvidenceFailure.amountNotInMessage =>
      'the extracted amount does not appear in the message',
    EvidenceFailure.amountIsBalance =>
      'the extracted amount matches a balance or limit, not a movement',
    EvidenceFailure.authorizationOnly =>
      'the message authorises a payment rather than reporting a completed one',
  };
}

final _authorizationPattern = RegExp(
  r'\b(otp|one[\s-]?time[\s-]?password|verification code|secret code)\b',
  caseSensitive: false,
);

/// Vocabulary that only appears once money has actually moved. Its presence
/// means a message mentioning an OTP is still reporting a real transaction
/// (for example a debit alert that also warns about OTP sharing).
final _completionPattern = RegExp(
  r'\b(debited|credited|spent|withdrawn|deducted|charged|'
  r'has been (?:debited|credited|reversed|paid)|reversed|'
  r'payment (?:of|received)|successful(?:ly)?)\b',
  caseSensitive: false,
);

/// True when [body] is authorising a payment rather than reporting one.
///
/// Measured against a real 3,253 message inbox: 507 messages matched the
/// authorisation pattern and none of them contained completion vocabulary,
/// so this rule dropped no genuine transactions while removing the largest
/// source of double counting.
bool isAuthorizationOnly(String body) =>
    _authorizationPattern.hasMatch(body) && !_completionPattern.hasMatch(body);

/// Checks a model-extracted amount against the message it came from.
///
/// Returns `null` when the extraction is supported by the text.
EvidenceFailure? verifyExtractedAmount({
  required String body,
  required int amountMinor,
  required String currency,
}) {
  if (isAuthorizationOnly(body)) return EvidenceFailure.authorizationOnly;

  final literals = amountLiteralsIn(body, currency);
  if (literals.isEmpty) return EvidenceFailure.amountNotInMessage;

  final matches = literals
      .where((literal) => literal.minorUnits == amountMinor)
      .toList();
  if (matches.isEmpty) return EvidenceFailure.amountNotInMessage;

  // Accepted when at least one occurrence is not in balance context; banks
  // often repeat the same figure as both the debit and the running balance.
  if (matches.every((literal) => literal.looksLikeBalance)) {
    return EvidenceFailure.amountIsBalance;
  }
  return null;
}
