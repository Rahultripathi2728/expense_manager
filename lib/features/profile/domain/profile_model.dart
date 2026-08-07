class Profile {
  final String id;
  final String userId;
  final String fullName;
  final String? username;
  final String? avatarUrl;
  final double monthlyBudget;
  final String? upiId;
  final DateTime createdAt;

  const Profile({
    required this.id,
    required this.userId,
    required this.fullName,
    this.username,
    this.avatarUrl,
    this.monthlyBudget = 0,
    this.upiId,
    required this.createdAt,
  });

  /// Validate username: lowercase, 3-20 chars, [a-z0-9_] only
  static bool isValidUsername(String username) {
    return RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(username);
  }

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['\$id'] ?? '',
      userId: map['userId'] ?? '',
      fullName: map['fullName'] ?? '',
      username: map['username'],
      avatarUrl: map['avatarUrl'],
      monthlyBudget: (map['monthlyBudget'] ?? 0).toDouble(),
      upiId: map['upiId'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'fullName': fullName,
    'username': username,
    'avatarUrl': avatarUrl,
    'monthlyBudget': monthlyBudget,
    'upiId': upiId,
    'createdAt': createdAt.toIso8601String(),
  };

  Profile copyWith({
    String? fullName,
    String? username,
    String? avatarUrl,
    double? monthlyBudget,
    String? upiId,
  }) {
    return Profile(
      id: id,
      userId: userId,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      upiId: upiId ?? this.upiId,
      createdAt: createdAt,
    );
  }
}

