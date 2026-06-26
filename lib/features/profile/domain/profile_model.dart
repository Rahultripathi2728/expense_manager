class Profile {
  final String id;
  final String userId;
  final String fullName;
  final String? avatarUrl;
  final double monthlyBudget;
  final String? upiId;
  final DateTime createdAt;

  const Profile({
    required this.id,
    required this.userId,
    required this.fullName,
    this.avatarUrl,
    this.monthlyBudget = 0,
    this.upiId,
    required this.createdAt,
  });

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['\$id'] ?? '',
      userId: map['userId'] ?? '',
      fullName: map['fullName'] ?? '',
      avatarUrl: map['avatarUrl'],
      monthlyBudget: (map['monthlyBudget'] ?? 0).toDouble(),
      upiId: map['upiId'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'fullName': fullName,
    'avatarUrl': avatarUrl,
    'monthlyBudget': monthlyBudget,
    'upiId': upiId,
    'createdAt': createdAt.toIso8601String(),
  };

  Profile copyWith({
    String? fullName,
    String? avatarUrl,
    double? monthlyBudget,
    String? upiId,
  }) {
    return Profile(
      id: id,
      userId: userId,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      upiId: upiId ?? this.upiId,
      createdAt: createdAt,
    );
  }
}
