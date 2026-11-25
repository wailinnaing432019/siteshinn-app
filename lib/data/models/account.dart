class Account {
  final String id;
  final String name;
  final String currencyCode;
  final DateTime createdAt;

  const Account({
    required this.id,
    required this.name,
    required this.currencyCode,
    required this.createdAt,
  });

  Account copyWith({
    String? id,
    String? name,
    String? currencyCode,
    DateTime? createdAt,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      currencyCode: currencyCode ?? this.currencyCode,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'currency_code': currencyCode,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] as String,
      name: map['name'] as String,
      currencyCode: map['currency_code'] as String? ?? 'MMK',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
