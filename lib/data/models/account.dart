enum AccountType {
  group('group'),
  personal('personal');

  final String key;
  const AccountType(this.key);

  static AccountType fromKey(String? key) {
    return AccountType.values.firstWhere(
      (t) => t.key == key,
      orElse: () => AccountType.group,
    );
  }
}

class Account {
  final String id;
  final String name;
  final String currencyCode;
  final AccountType accountType;
  final double openingBalance;
  final DateTime createdAt;

  const Account({
    required this.id,
    required this.name,
    required this.currencyCode,
    this.accountType = AccountType.group,
    this.openingBalance = 0,
    required this.createdAt,
  });

  bool get isPersonal => accountType == AccountType.personal;
  bool get isGroup => accountType == AccountType.group;

  Account copyWith({
    String? id,
    String? name,
    String? currencyCode,
    AccountType? accountType,
    double? openingBalance,
    DateTime? createdAt,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      currencyCode: currencyCode ?? this.currencyCode,
      accountType: accountType ?? this.accountType,
      openingBalance: openingBalance ?? this.openingBalance,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'currency_code': currencyCode,
      'account_type': accountType.key,
      'opening_balance': openingBalance,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] as String,
      name: map['name'] as String,
      currencyCode: map['currency_code'] as String? ?? 'MMK',
      accountType: AccountType.fromKey(map['account_type'] as String?),
      openingBalance: (map['opening_balance'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
