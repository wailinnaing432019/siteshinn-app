enum TransactionType {
  expense('expense'),
  income('income');

  final String key;
  const TransactionType(this.key);

  static TransactionType fromKey(String? key) {
    return TransactionType.values.firstWhere(
      (t) => t.key == key,
      orElse: () => TransactionType.expense,
    );
  }
}

enum ExpenseCategory {
  food('food'),
  cooking('cooking'),
  utilities('utilities'),
  household('household'),
  transport('transport'),
  shopping('shopping'),
  health('health'),
  salary('salary'),
  business('business'),
  gift('gift'),
  refund('refund'),
  otherIncome('other_income'),
  other('other');

  final String key;
  const ExpenseCategory(this.key);

  static const List<ExpenseCategory> groupExpenseCategories = [
    food,
    cooking,
    utilities,
    household,
    other,
  ];

  static const List<ExpenseCategory> personalExpenseCategories = [
    food,
    transport,
    utilities,
    shopping,
    health,
    household,
    other,
  ];

  static const List<ExpenseCategory> incomeCategories = [
    salary,
    business,
    gift,
    refund,
    otherIncome,
  ];

  static ExpenseCategory fromKey(String? key) {
    return ExpenseCategory.values.firstWhere(
      (c) => c.key == key,
      orElse: () => ExpenseCategory.other,
    );
  }
}

class ExpenseSplit {
  final String id;
  final String expenseId;
  final String memberId;
  final double shareAmount;

  const ExpenseSplit({
    required this.id,
    required this.expenseId,
    required this.memberId,
    required this.shareAmount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'expense_id': expenseId,
      'member_id': memberId,
      'share_amount': shareAmount,
    };
  }

  factory ExpenseSplit.fromMap(Map<String, dynamic> map) {
    return ExpenseSplit(
      id: map['id'] as String,
      expenseId: map['expense_id'] as String,
      memberId: map['member_id'] as String,
      shareAmount: (map['share_amount'] as num).toDouble(),
    );
  }
}

class Expense {
  final String id;
  final String accountId;
  final String cycleId;
  final String? paidByMemberId;
  final TransactionType txType;
  final String title;
  final ExpenseCategory category;
  final double amount;
  final DateTime expenseDate;
  final DateTime createdAt;
  final List<ExpenseSplit> splits;

  const Expense({
    required this.id,
    required this.accountId,
    required this.cycleId,
    this.paidByMemberId,
    this.txType = TransactionType.expense,
    required this.title,
    required this.category,
    required this.amount,
    required this.expenseDate,
    required this.createdAt,
    this.splits = const [],
  });

  bool get isIncome => txType == TransactionType.income;
  bool get isExpense => txType == TransactionType.expense;

  Expense copyWith({
    String? id,
    String? accountId,
    String? cycleId,
    String? paidByMemberId,
    TransactionType? txType,
    String? title,
    ExpenseCategory? category,
    double? amount,
    DateTime? expenseDate,
    DateTime? createdAt,
    List<ExpenseSplit>? splits,
  }) {
    return Expense(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      cycleId: cycleId ?? this.cycleId,
      paidByMemberId: paidByMemberId ?? this.paidByMemberId,
      txType: txType ?? this.txType,
      title: title ?? this.title,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      expenseDate: expenseDate ?? this.expenseDate,
      createdAt: createdAt ?? this.createdAt,
      splits: splits ?? this.splits,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'account_id': accountId,
      'cycle_id': cycleId,
      'paid_by_member_id': paidByMemberId,
      'tx_type': txType.key,
      'title': title,
      'category': category.key,
      'amount': amount,
      'expense_date': expenseDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Expense.fromMap(
    Map<String, dynamic> map, {
    List<ExpenseSplit> splits = const [],
  }) {
    return Expense(
      id: map['id'] as String,
      accountId: map['account_id'] as String,
      cycleId: map['cycle_id'] as String,
      paidByMemberId: map['paid_by_member_id'] as String?,
      txType: TransactionType.fromKey(map['tx_type'] as String?),
      title: map['title'] as String,
      category: ExpenseCategory.fromKey(map['category'] as String?),
      amount: (map['amount'] as num).toDouble(),
      expenseDate: DateTime.parse(map['expense_date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      splits: splits,
    );
  }
}
