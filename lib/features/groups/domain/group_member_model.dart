class GroupMember {
  final String id;
  final String groupId;
  final String userId;
  final DateTime joinedAt;
  final String role; // 'admin' | 'member'

  const GroupMember({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.joinedAt,
    required this.role,
  });

  bool get isAdmin => role == 'admin';

  factory GroupMember.fromMap(Map<String, dynamic> map) {
    return GroupMember(
      id: map['\$id'] ?? '',
      groupId: map['groupId'] ?? '',
      userId: map['userId'] ?? '',
      joinedAt: DateTime.parse(map['joinedAt']),
      role: map['role'] ?? 'member',
    );
  }

  Map<String, dynamic> toMap() => {
    'groupId': groupId,
    'userId': userId,
    'joinedAt': joinedAt.toIso8601String(),
    'role': role,
  };
}
