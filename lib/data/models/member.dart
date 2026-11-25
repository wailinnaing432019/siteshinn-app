class Member {
  final String id;
  final String accountId;
  final String name;
  final bool isActive;
  final DateTime createdAt;

  const Member({
    required this.id,
    required this.accountId,
    required this.name,
    this.isActive = true,
    required this.createdAt,
  });

  Member copyWith({
    String? id,
    String? accountId,
    String? name,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Member(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'account_id': accountId,
      'name': name,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Member.fromMap(Map<String, dynamic> map) {
    return Member(
      id: map['id'] as String,
      accountId: map['account_id'] as String,
      name: map['name'] as String,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
