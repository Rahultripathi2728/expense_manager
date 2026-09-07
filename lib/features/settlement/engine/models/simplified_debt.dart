/// Represents a simplified cash payment debt transfer between two members.
class SimplifiedDebt {
  final String fromUserId;
  final String toUserId;
  final double amount;

  const SimplifiedDebt({
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
  });

  @override
  String toString() => 'SimplifiedDebt(from: $fromUserId, to: $toUserId, amount: $amount)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SimplifiedDebt &&
          runtimeType == other.runtimeType &&
          fromUserId == other.fromUserId &&
          toUserId == other.toUserId &&
          amount == other.amount;

  @override
  int get hashCode => fromUserId.hashCode ^ toUserId.hashCode ^ amount.hashCode;
}
