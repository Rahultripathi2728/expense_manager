class Expense {
  final String id;
  final String userId;
  final String? groupId;
  final String description;
  final double amount;
  final String category;
  final String expenseType; // 'personal' | 'group'
  final String? splitType; // 'equal' | 'unequal' | 'itemwise' | 'none'
  final DateTime expenseDate;
  final bool isSettled;
  final DateTime? settledAt;
  final DateTime createdAt;

  const Expense({
    required this.id,
    required this.userId,
    this.groupId,
    required this.description,
    required this.amount,
    required this.category,
    required this.expenseType,
    this.splitType,
    required this.expenseDate,
    this.isSettled = false,
    this.settledAt,
    required this.createdAt,
  });

  bool get isPersonal => expenseType == 'personal';
  bool get isGroup => expenseType == 'group';

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['\$id'] ?? '',
      userId: map['userId'] ?? '',
      groupId: map['groupId'],
      description: map['description'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      category: map['category'] ?? 'other',
      expenseType: map['expenseType'] ?? 'personal',
      splitType: map['splitType'],
      expenseDate: DateTime.parse(map['expenseDate']),
      isSettled: map['isSettled'] ?? false,
      settledAt: map['settledAt'] != null
          ? DateTime.parse(map['settledAt'])
          : null,
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'groupId': groupId,
    'description': description,
    'amount': amount,
    'category': category,
    'expenseType': expenseType,
    'splitType': splitType,
    'expenseDate': expenseDate.toIso8601String(),
    'isSettled': isSettled,
    'settledAt': settledAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };
}
