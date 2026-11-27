class Member {
  final String id;
  final String accountId;
  final String? userId;
  final String name;
  final bool isActive;
  final DateTime createdAt;

  const Member({
    required this.id,
    required this.accountId,
    this.userId,
    required this.name,
    this.isActive = true,
    required this.createdAt,
  });

  Member copyWith({
    String? id,
    String? accountId,
    String? userId,
    String? name,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Member(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'account_id': accountId,
      'user_id': userId,
      'name': name,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Member.fromMap(Map<String, dynamic> map) {
    final rawActive = map['is_active'];
    final active = rawActive is bool ? rawActive : ((rawActive as int? ?? 1) == 1);
    return Member(
      id: map['id'] as String,
      accountId: map['account_id'] as String,
      userId: map['user_id'] as String?,
      name: map['name'] as String,
      isActive: active,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
