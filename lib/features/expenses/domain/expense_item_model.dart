class ExpenseItem {
  final String id;
  final String expenseId;
  final String itemName;
  final double itemAmount;
  final List<String> participants;

  const ExpenseItem({
    required this.id,
    required this.expenseId,
    required this.itemName,
    required this.itemAmount,
    required this.participants,
  });

  factory ExpenseItem.fromMap(Map<String, dynamic> map) {
    return ExpenseItem(
      id: map['\$id'] ?? '',
      expenseId: map['expenseId'] ?? '',
      itemName: map['itemName'] ?? '',
      itemAmount: (map['itemAmount'] ?? 0).toDouble(),
      participants: List<String>.from(map['participants'] ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
    'expenseId': expenseId,
    'itemName': itemName,
    'itemAmount': itemAmount,
    'participants': participants,
  };
}
