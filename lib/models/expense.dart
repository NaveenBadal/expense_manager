class Expense {
  final int? id;
  final double amount;
  final String currency;
  final String merchant;
  final String category;
  final DateTime date;
  final String originalSms;
  final String type; // 'expense' | 'income'
  final String tags; // comma-separated labels
  final String? normalizedMerchant;

  Expense({
    this.id,
    required this.amount,
    required this.currency,
    required this.merchant,
    required this.category,
    required this.date,
    required this.originalSms,
    this.type = 'expense',
    this.tags = '',
    this.normalizedMerchant,
  });

  bool get isIncome => type == 'income';

  /// Cleaned merchant name for display; falls back to raw merchant.
  String get displayMerchant => normalizedMerchant ?? merchant;

  /// Parsed tag list from the comma-separated [tags] field.
  List<String> get tagList => tags.isEmpty
      ? []
      : tags
            .split(',')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList();

  Expense copyWith({
    int? id,
    double? amount,
    String? currency,
    String? merchant,
    String? category,
    DateTime? date,
    String? originalSms,
    String? type,
    String? tags,
    String? normalizedMerchant,
  }) => Expense(
    id: id ?? this.id,
    amount: amount ?? this.amount,
    currency: currency ?? this.currency,
    merchant: merchant ?? this.merchant,
    category: category ?? this.category,
    date: date ?? this.date,
    originalSms: originalSms ?? this.originalSms,
    type: type ?? this.type,
    tags: tags ?? this.tags,
    normalizedMerchant: normalizedMerchant ?? this.normalizedMerchant,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'amount': amount,
    'currency': currency,
    'merchant': merchant,
    'category': category,
    'date': date.toIso8601String(),
    'originalSms': originalSms,
    'type': type,
    'tags': tags,
    'normalized_merchant': normalizedMerchant,
  };

  factory Expense.fromMap(Map<String, dynamic> map) => Expense(
    id: map['id'] as int?,
    amount: (map['amount'] as num).toDouble(),
    currency: map['currency'] as String,
    merchant: map['merchant'] as String,
    category: map['category'] as String,
    date: DateTime.parse(map['date'] as String),
    originalSms: map['originalSms'] as String,
    type: map['type'] as String? ?? 'expense',
    tags: map['tags'] as String? ?? '',
    normalizedMerchant: map['normalized_merchant'] as String?,
  );
}
