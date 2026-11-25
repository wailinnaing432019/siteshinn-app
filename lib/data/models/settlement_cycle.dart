class SettlementCycle {
  final String id;
  final String accountId;
  final String title;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isSettled;

  const SettlementCycle({
    required this.id,
    required this.accountId,
    required this.title,
    required this.startDate,
    this.endDate,
    this.isSettled = false,
  });

  SettlementCycle copyWith({
    String? id,
    String? accountId,
    String? title,
    DateTime? startDate,
    DateTime? endDate,
    bool? isSettled,
  }) {
    return SettlementCycle(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      title: title ?? this.title,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isSettled: isSettled ?? this.isSettled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'account_id': accountId,
      'title': title,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'is_settled': isSettled ? 1 : 0,
    };
  }

  factory SettlementCycle.fromMap(Map<String, dynamic> map) {
    return SettlementCycle(
      id: map['id'] as String,
      accountId: map['account_id'] as String,
      title: map['title'] as String,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: map['end_date'] != null
          ? DateTime.parse(map['end_date'] as String)
          : null,
      isSettled: (map['is_settled'] as int? ?? 0) == 1,
    );
  }
}
