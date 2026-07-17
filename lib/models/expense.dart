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
  final String? account;
  final String? counterpartyAccount;
  final String status;
  final String source;
  final double confidence;
  final String? transferGroup;
  final String notes;

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
    this.account,
    this.counterpartyAccount,
    this.status = 'settled',
    this.source = 'manual',
    this.confidence = 1,
    this.transferGroup,
    this.notes = '',
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
    String? account,
    String? counterpartyAccount,
    String? status,
    String? source,
    double? confidence,
    String? transferGroup,
    String? notes,
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
    account: account ?? this.account,
    counterpartyAccount: counterpartyAccount ?? this.counterpartyAccount,
    status: status ?? this.status,
    source: source ?? this.source,
    confidence: confidence ?? this.confidence,
    transferGroup: transferGroup ?? this.transferGroup,
    notes: notes ?? this.notes,
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
    'account': account,
    'counterparty_account': counterpartyAccount,
    'status': status,
    'source': source,
    'confidence': confidence,
    'transfer_group': transferGroup,
    'notes': notes,
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
    account: map['account'] as String?,
    counterpartyAccount: map['counterparty_account'] as String?,
    status: map['status'] as String? ?? 'settled',
    source: map['source'] as String? ?? 'manual',
    confidence: (map['confidence'] as num?)?.toDouble() ?? 1,
    transferGroup: map['transfer_group'] as String?,
    notes: map['notes'] as String? ?? '',
  );
}
