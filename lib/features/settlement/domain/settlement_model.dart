class Settlement {
  final String id;
  final String groupId;
  final String fromUserId;
  final String toUserId;
  final double amount;
  final List<String> settledExpenseIds;
  final DateTime createdAt;

  const Settlement({
    required this.id,
    required this.groupId,
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    required this.settledExpenseIds,
    required this.createdAt,
  });

  factory Settlement.fromMap(Map<String, dynamic> map) {
    return Settlement(
      id: map['\$id'] ?? '',
      groupId: map['groupId'] ?? '',
      fromUserId: map['fromUserId'] ?? '',
      toUserId: map['toUserId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      settledExpenseIds: List<String>.from(map['settledExpenseIds'] ?? []),
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'groupId': groupId,
    'fromUserId': fromUserId,
    'toUserId': toUserId,
    'amount': amount,
    'settledExpenseIds': settledExpenseIds,
    'createdAt': createdAt.toIso8601String(),
  };
}
