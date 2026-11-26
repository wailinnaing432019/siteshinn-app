import 'account.dart';
import 'expense.dart';

class PersonalLedgerSummary {
  final double openingBalance;
  final double totalIncome;
  final double totalExpense;
  final double currentBalance;
  final double periodIncome;
  final double periodExpense;
  final List<Expense> filteredTransactions;

  const PersonalLedgerSummary({
    required this.openingBalance,
    required this.totalIncome,
    required this.totalExpense,
    required this.currentBalance,
    required this.periodIncome,
    required this.periodExpense,
    required this.filteredTransactions,
  });

  factory PersonalLedgerSummary.compute({
    required Account account,
    required List<Expense> allTransactions,
    DateTime? startDate,
    DateTime? endDate,
    TransactionType? typeFilter,
    String searchQuery = '',
  }) {
    var totalIncome = 0.0;
    var totalExpense = 0.0;
    var periodIncome = 0.0;
    var periodExpense = 0.0;

    final startDay = startDate != null
        ? DateTime(startDate.year, startDate.month, startDate.day)
        : null;
    final endDay = endDate != null
        ? DateTime(endDate.year, endDate.month, endDate.day)
        : null;

    final filtered = <Expense>[];
    final q = searchQuery.trim().toLowerCase();

    for (final tx in allTransactions) {
      if (tx.isIncome) {
        totalIncome += tx.amount;
      } else {
        totalExpense += tx.amount;
      }

      final txDay = DateTime(
        tx.expenseDate.year,
        tx.expenseDate.month,
        tx.expenseDate.day,
      );
      if (startDay != null && txDay.isBefore(startDay)) {
        continue;
      }
      if (endDay != null && txDay.isAfter(endDay)) {
        continue;
      }

      if (tx.isIncome) {
        periodIncome += tx.amount;
      } else {
        periodExpense += tx.amount;
      }

      if (typeFilter != null && tx.txType != typeFilter) {
        continue;
      }
      if (q.isNotEmpty && !tx.title.toLowerCase().contains(q)) {
        continue;
      }
      filtered.add(tx);
    }

    return PersonalLedgerSummary(
      openingBalance: account.openingBalance,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      currentBalance: account.openingBalance + totalIncome - totalExpense,
      periodIncome: periodIncome,
      periodExpense: periodExpense,
      filteredTransactions: filtered,
    );
  }
}
