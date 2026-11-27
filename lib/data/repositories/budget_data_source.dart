import '../models/account.dart';
import '../models/expense.dart';
import '../models/member.dart';
import '../models/settlement_cycle.dart';
import '../models/settlement_summary.dart';

class GroupInvitePreview {
  final String accountId;
  final String name;
  final String currencyCode;
  final List<({String id, String name})> unclaimedMembers;

  const GroupInvitePreview({
    required this.accountId,
    required this.name,
    required this.currencyCode,
    required this.unclaimedMembers,
  });
}

abstract class BudgetDataSource {
  Future<List<Account>> getAccounts();

  Future<Account> createAccount({
    required String name,
    required String currencyCode,
    required AccountType accountType,
    double openingBalance = 0,
    List<String> memberNames = const [],
    String? creatorMemberName,
  });

  Future<void> updateAccount(Account account);

  Future<List<Member>> getMembers(String accountId);

  Future<Member> addMember({
    required String accountId,
    required String name,
  });

  Future<void> updateMember(Member member);

  Future<SettlementCycle> getOrCreateOpenCycle(String accountId);

  Future<List<SettlementCycle>> getSettledCycles(String accountId);

  Future<void> closeCycleAndStartNext({
    required SettlementCycle cycle,
    required String settledTitle,
    required List<SettlementTransfer> transfers,
  });

  Future<List<SettlementTransfer>> getTransfersForCycle({
    required String cycleId,
    required Map<String, Member> memberById,
  });

  Future<void> markTransferPaid({
    required String transferId,
    required bool isPaid,
  });

  Future<List<Expense>> getExpensesForCycle(String cycleId);

  Future<List<Expense>> getTransactionsForAccount(String accountId);

  Future<void> saveTransaction({
    String? existingExpenseId,
    required String accountId,
    required String cycleId,
    String? paidByMemberId,
    TransactionType txType = TransactionType.expense,
    required String title,
    required ExpenseCategory category,
    required double amount,
    required DateTime expenseDate,
    List<String> participantIds = const [],
    required String currencyCode,
  });

  Future<void> deleteExpense(String expenseId);
}
