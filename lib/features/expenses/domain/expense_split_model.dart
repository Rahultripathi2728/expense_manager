class ExpenseSplit {
  final String id;
  final String expenseId;
  final String userId;
  final double amountOwed;
  final bool isIncluded;

  const ExpenseSplit({
    required this.id,
    required this.expenseId,
    required this.userId,
    required this.amountOwed,
    this.isIncluded = true,
  });

  factory ExpenseSplit.fromMap(Map<String, dynamic> map) {
    return ExpenseSplit(
      id: map['\$id'] ?? '',
      expenseId: map['expenseId'] ?? '',
      userId: map['userId'] ?? '',
      amountOwed: (map['amountOwed'] ?? 0).toDouble(),
      isIncluded: map['isIncluded'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'expenseId': expenseId,
    'userId': userId,
    'amountOwed': amountOwed,
    'isIncluded': isIncluded,
  };
}
