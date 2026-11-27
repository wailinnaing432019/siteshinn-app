import 'expense.dart';
import 'member.dart';
import 'settlement_cycle.dart';

class MemberBalance {
  final Member member;
  final double totalPaid;
  final double totalShare;
  final double advanceGiven;
  final double advanceReceived;
  final double netBalance;

  const MemberBalance({
    required this.member,
    required this.totalPaid,
    required this.totalShare,
    this.advanceGiven = 0,
    this.advanceReceived = 0,
    required this.netBalance,
  });

  double get advanceNet => advanceGiven - advanceReceived;
}

class SettlementTransfer {
  final String id;
  final String cycleId;
  final String fromMemberId;
  final String toMemberId;
  final String fromMemberName;
  final String toMemberName;
  final double amount;
  final bool isPaid;
  final DateTime? paidAt;

  const SettlementTransfer({
    required this.id,
    required this.cycleId,
    required this.fromMemberId,
    required this.toMemberId,
    required this.fromMemberName,
    required this.toMemberName,
    required this.amount,
    this.isPaid = false,
    this.paidAt,
  });

  SettlementTransfer copyWith({
    bool? isPaid,
    DateTime? paidAt,
  }) {
    return SettlementTransfer(
      id: id,
      cycleId: cycleId,
      fromMemberId: fromMemberId,
      toMemberId: toMemberId,
      fromMemberName: fromMemberName,
      toMemberName: toMemberName,
      amount: amount,
      isPaid: isPaid ?? this.isPaid,
      paidAt: paidAt ?? this.paidAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cycle_id': cycleId,
      'from_member_id': fromMemberId,
      'to_member_id': toMemberId,
      'amount': amount,
      'is_paid': isPaid ? 1 : 0,
      'paid_at': paidAt?.toIso8601String(),
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

  int get expenseCount => expenses.where((e) => !e.isAdvance).length;

  int get advanceCount => expenses.where((e) => e.isAdvance).length;

  double get averagePerMember =>
      balances.isEmpty ? 0 : totalExpense / balances.length;
}
