class Group {
  final String id;
  final String name;
  final String joinCode;
  final String createdBy;
  final DateTime createdAt;

  const Group({
    required this.id,
    required this.name,
    required this.joinCode,
    required this.createdBy,
    required this.createdAt,
  });

  factory Group.fromMap(Map<String, dynamic> map) {
    return Group(
      id: map['\$id'] ?? '',
      name: map['name'] ?? '',
      joinCode: map['joinCode'] ?? '',
      createdBy: map['createdBy'] ?? '',
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'joinCode': joinCode,
    'createdBy': createdBy,
    'createdAt': createdAt.toIso8601String(),
  };
}
