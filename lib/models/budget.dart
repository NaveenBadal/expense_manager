class Budget {
  const Budget({
    this.id,
    required this.name,
    required this.amount,
    required this.currency,
    this.category,
    this.warningPercent = 75,
    required this.createdAt,
  });

  final int? id;
  final String name;
  final double amount;
  final String currency;
  final String? category;
  final int warningPercent;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'amount': amount,
    'currency': currency,
    'category': category,
    'warning_percent': warningPercent,
    'created_at': createdAt.toIso8601String(),
  };

  factory Budget.fromMap(Map<String, dynamic> map) => Budget(
    id: map['id'] as int?,
    name: map['name'].toString(),
    amount: (map['amount'] as num).toDouble(),
    currency: map['currency'].toString(),
    category: map['category'] as String?,
    warningPercent: (map['warning_percent'] as num?)?.toInt() ?? 75,
    createdAt: DateTime.parse(map['created_at'].toString()),
  );
}
