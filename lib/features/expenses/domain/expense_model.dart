import 'dart:convert';

class Expense {
  final String id;
  final String userId;
  final String? groupId;
  final String description;
  final double amount;
  final String category;
  final String expenseType; // 'personal' | 'group'
  final String? splitType; // 'equal' | 'unequal' | 'itemwise' | 'none'
  final List<Map<String, dynamic>>? splitItems;
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
    this.splitItems,
    required this.expenseDate,
    this.isSettled = false,
    this.settledAt,
    required this.createdAt,
  });

  bool get isPersonal => expenseType == 'personal';
  bool get isGroup => expenseType == 'group';

  factory Expense.fromMap(Map<String, dynamic> map) {
    List<Map<String, dynamic>>? parsedItems;
    if (map['splitItems'] != null) {
      if (map['splitItems'] is String) {
        try {
          final List<dynamic> decoded = jsonDecode(map['splitItems']);
          parsedItems = decoded.map((e) => e as Map<String, dynamic>).toList();
        } catch (_) {}
      } else if (map['splitItems'] is List) {
        parsedItems = List<Map<String, dynamic>>.from(map['splitItems']);
      }
    }

    return Expense(
      id: map['\$id'] ?? '',
      userId: map['userId'] ?? '',
      groupId: map['groupId'],
      description: map['description'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      category: map['category'] ?? 'other',
      expenseType: map['expenseType'] ?? 'personal',
      splitType: map['splitType'],
      splitItems: parsedItems,
      expenseDate: DateTime.parse(map['expenseDate']),
      isSettled: map['isSettled'] ?? false,
      settledAt: map['settledAt'] != null
          ? DateTime.parse(map['settledAt'])
          : null,
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'groupId': groupId,
      'description': description,
      'amount': amount,
      'category': category,
      'expenseType': expenseType,
      'splitType': splitType,
      'splitItems': splitItems != null ? jsonEncode(splitItems) : null,
      'expenseDate': expenseDate.toIso8601String(),
      'isSettled': isSettled,
      'settledAt': settledAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
