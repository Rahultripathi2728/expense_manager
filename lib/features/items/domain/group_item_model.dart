class ItemDraft {
  String title;
  String quantity;
  ItemDraft({this.title = '', this.quantity = ''});
}

class GroupItem {
  final String id;
  final String groupId;
  final String groupName;
  final String title;
  final String quantity;
  final String addedBy;
  final String addedByName;
  final bool isBought;
  final String? boughtBy;
  final String? boughtByName;
  final DateTime createdAt;
  final DateTime? boughtAt;

  const GroupItem({
    required this.id,
    required this.groupId,
    this.groupName = '',
    required this.title,
    this.quantity = '',
    required this.addedBy,
    required this.addedByName,
    this.isBought = false,
    this.boughtBy,
    this.boughtByName,
    required this.createdAt,
    this.boughtAt,
  });

  bool get isPersonal => groupId.isEmpty || groupId == 'personal';

  GroupItem copyWith({
    String? id,
    String? groupId,
    String? groupName,
    String? title,
    String? quantity,
    String? addedBy,
    String? addedByName,
    bool? isBought,
    String? boughtBy,
    String? boughtByName,
    DateTime? createdAt,
    DateTime? boughtAt,
  }) {
    return GroupItem(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      title: title ?? this.title,
      quantity: quantity ?? this.quantity,
      addedBy: addedBy ?? this.addedBy,
      addedByName: addedByName ?? this.addedByName,
      isBought: isBought ?? this.isBought,
      boughtBy: boughtBy ?? this.boughtBy,
      boughtByName: boughtByName ?? this.boughtByName,
      createdAt: createdAt ?? this.createdAt,
      boughtAt: boughtAt ?? this.boughtAt,
    );
  }

  factory GroupItem.fromMap(Map<String, dynamic> map) {
    return GroupItem(
      id: map['\$id'] ?? map['id'] ?? '',
      groupId: map['groupId'] ?? '',
      groupName: map['groupName'] ?? (map['groupId'] == 'personal' ? 'Personal' : ''),
      title: map['itemName'] ?? map['title'] ?? map['name'] ?? '',
      quantity: map['quantity'] ?? '',
      addedBy: map['addedBy'] ?? map['userId'] ?? '',
      addedByName: map['addedByName'] ?? 'Member',
      isBought: map['isPurchased'] == true || map['isBought'] == true,
      boughtBy: map['boughtBy'],
      boughtByName: map['boughtByName'],
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      boughtAt: map['boughtAt'] != null
          ? DateTime.tryParse(map['boughtAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': groupId,
      'groupName': groupName,
      'title': title,
      'quantity': quantity,
      'addedBy': addedBy,
      'addedByName': addedByName,
      'isBought': isBought,
      'boughtBy': boughtBy,
      'boughtByName': boughtByName,
      'createdAt': createdAt.toIso8601String(),
      'boughtAt': boughtAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toAppwriteMap() {
    return {
      'userId': addedBy,
      if (groupId.isNotEmpty && groupId != 'personal') 'groupId': groupId,
      'itemName': title,
      if (quantity.isNotEmpty) 'quantity': quantity,
      'isPurchased': isBought,
      'addedBy': addedBy,
      if (groupName.isNotEmpty) 'groupName': groupName,
      if (addedByName.isNotEmpty) 'addedByName': addedByName,
      if (boughtBy != null) 'boughtBy': boughtBy,
      if (boughtByName != null) 'boughtByName': boughtByName,
      if (boughtAt != null) 'boughtAt': boughtAt!.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
