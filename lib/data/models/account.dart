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
  final String? ownerId;
  final String name;
  final String currencyCode;
  final AccountType accountType;
  final double openingBalance;
  final String? inviteCode;
  final DateTime createdAt;

  const Account({
    required this.id,
    this.ownerId,
    required this.name,
    required this.currencyCode,
    this.accountType = AccountType.group,
    this.openingBalance = 0,
    this.inviteCode,
    required this.createdAt,
  });

  bool get isPersonal => accountType == AccountType.personal;
  bool get isGroup => accountType == AccountType.group;

  Account copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? currencyCode,
    AccountType? accountType,
    double? openingBalance,
    String? inviteCode,
    DateTime? createdAt,
  }) {
    return Account(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      currencyCode: currencyCode ?? this.currencyCode,
      accountType: accountType ?? this.accountType,
      openingBalance: openingBalance ?? this.openingBalance,
      inviteCode: inviteCode ?? this.inviteCode,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'owner_id': ownerId,
      'name': name,
      'currency_code': currencyCode,
      'account_type': accountType.key,
      'opening_balance': openingBalance,
      'invite_code': inviteCode,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String?,
      name: map['name'] as String,
      currencyCode: map['currency_code'] as String? ?? 'MMK',
      accountType: AccountType.fromKey(map['account_type'] as String?),
      openingBalance: (map['opening_balance'] as num?)?.toDouble() ?? 0,
      inviteCode: map['invite_code'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
