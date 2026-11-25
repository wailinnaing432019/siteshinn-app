import 'expense.dart';
import 'member.dart';
import 'settlement_cycle.dart';

class MemberBalance {
  final Member member;
  final double totalPaid;
  final double totalShare;
  final double netBalance;

  const MemberBalance({
    required this.member,
    required this.totalPaid,
    required this.totalShare,
    required this.netBalance,
  });
}

class SettlementTransfer {
  final String id;
  final String cycleId;
  final String fromMemberId;
  final String toMemberId;
  final String fromMemberName;
  final String toMemberName;
  final double amount;

  const SettlementTransfer({
    required this.id,
    required this.cycleId,
    required this.fromMemberId,
    required this.toMemberId,
    required this.fromMemberName,
    required this.toMemberName,
    required this.amount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cycle_id': cycleId,
      'from_member_id': fromMemberId,
      'to_member_id': toMemberId,
      'amount': amount,
    };
  }
}

class CycleSettlementReport {
  final SettlementCycle cycle;
  final double totalExpense;
  final List<MemberBalance> balances;
  final List<SettlementTransfer> transfers;
  final List<Expense> expenses;

  const CycleSettlementReport({
    required this.cycle,
    required this.totalExpense,
    required this.balances,
    required this.transfers,
    required this.expenses,
  });

  int get activeParticipantCount => balances.length;

  double get averagePerMember =>
      balances.isEmpty ? 0 : totalExpense / balances.length;
}
