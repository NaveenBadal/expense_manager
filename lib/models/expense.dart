class Expense {
  final int? id;
  final double amount;
  final String currency;
  final String merchant;
  final String category;
  final DateTime date;
  final String originalSms;

  Expense({
    this.id,
    required this.amount,
    required this.currency,
    required this.merchant,
    required this.category,
    required this.date,
    required this.originalSms,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'currency': currency,
      'merchant': merchant,
      'category': category,
      'date': date.toIso8601String(),
      'originalSms': originalSms,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      amount: map['amount'],
      currency: map['currency'],
      merchant: map['merchant'],
      category: map['category'],
      date: DateTime.parse(map['date']),
      originalSms: map['originalSms'],
    );
  }
}
