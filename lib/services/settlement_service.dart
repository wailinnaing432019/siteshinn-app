import 'dart:math';

import 'package:uuid/uuid.dart';

import '../core/utils/formatters.dart';
import '../data/models/expense.dart';
import '../data/models/member.dart';
import '../data/models/settlement_cycle.dart';
import '../data/models/settlement_summary.dart';

class SettlementService {
  static const Uuid _uuid = Uuid();

  /// Converts a double amount to integer minor units (e.g., 1 Ks or 1 cent)
  /// so split and settlement arithmetic avoids floating-point drift.
  static int toMinorUnits(double amount, String currencyCode) {
    final decimals = AppFormatters.decimalsForCurrency(currencyCode);
    final factor = pow(10, decimals).toInt();
    return (amount * factor).round();
  }

  static double fromMinorUnits(int units, String currencyCode) {
    final decimals = AppFormatters.decimalsForCurrency(currencyCode);
    final factor = pow(10, decimals).toDouble();
    return units / factor;
  }

  /// Generates equal ExpenseSplit records whose sum equals [amount] exactly.
  static List<ExpenseSplit> buildEqualSplits({
    required String expenseId,
    required double amount,
    required List<String> participantIds,
    required String currencyCode,
  }) {
    if (participantIds.isEmpty) {
      throw ArgumentError('At least one participant is required for a split.');
    }
    final uniqueIds = participantIds.toSet().toList();
    final totalUnits = toMinorUnits(amount, currencyCode);
    final count = uniqueIds.length;
    final baseUnits = totalUnits ~/ count;
    final remainder = totalUnits % count;

    return List<ExpenseSplit>.generate(count, (index) {
      final shareUnits = baseUnits + (index < remainder ? 1 : 0);
      return ExpenseSplit(
        id: _uuid.v4(),
        expenseId: expenseId,
        memberId: uniqueIds[index],
        shareAmount: fromMinorUnits(shareUnits, currencyCode),
      );
    });
  }

  /// Computes per-member paid/share/net totals and minimal "who pays whom" transfers.
  static CycleSettlementReport calculateReport({
    required SettlementCycle cycle,
    required List<Member> allMembers,
    required List<Expense> expenses,
    required String currencyCode,
    List<SettlementTransfer>? savedTransfers,
  }) {
    // Include all active members plus any inactive member referenced in this cycle's expenses.
    final referencedMemberIds = <String>{};
    for (final expense in expenses) {
      if (expense.paidByMemberId != null) {
        referencedMemberIds.add(expense.paidByMemberId!);
      }
      for (final split in expense.splits) {
        referencedMemberIds.add(split.memberId);
      }
    }

    final relevantMembers = allMembers
        .where((m) => m.isActive || referencedMemberIds.contains(m.id))
        .toList();

    final paidUnitsByMember = <String, int>{
      for (final m in relevantMembers) m.id: 0,
    };
    final shareUnitsByMember = <String, int>{
      for (final m in relevantMembers) m.id: 0,
    };
    final advanceGivenUnitsByMember = <String, int>{
      for (final m in relevantMembers) m.id: 0,
    };
    final advanceReceivedUnitsByMember = <String, int>{
      for (final m in relevantMembers) m.id: 0,
    };

    var totalUnits = 0;

    for (final expense in expenses) {
      final expenseUnits = toMinorUnits(expense.amount, currencyCode);
      final payerId = expense.paidByMemberId;

      if (expense.isAdvance) {
        if (payerId != null) {
          advanceGivenUnitsByMember[payerId] =
              (advanceGivenUnitsByMember[payerId] ?? 0) + expenseUnits;
        }
        for (final split in expense.splits) {
          advanceReceivedUnitsByMember[split.memberId] =
              (advanceReceivedUnitsByMember[split.memberId] ?? 0) +
              toMinorUnits(split.shareAmount, currencyCode);
        }
        continue;
      }

      totalUnits += expenseUnits;
      if (payerId != null) {
        paidUnitsByMember[payerId] =
            (paidUnitsByMember[payerId] ?? 0) + expenseUnits;
      }

      if (expense.splits.isNotEmpty) {
        for (final split in expense.splits) {
          shareUnitsByMember[split.memberId] =
              (shareUnitsByMember[split.memberId] ?? 0) +
              toMinorUnits(split.shareAmount, currencyCode);
        }
      } else if (relevantMembers.isNotEmpty) {
        final fallback = buildEqualSplits(
          expenseId: expense.id,
          amount: expense.amount,
          participantIds: relevantMembers.map((m) => m.id).toList(),
          currencyCode: currencyCode,
        );
        for (final split in fallback) {
          shareUnitsByMember[split.memberId] =
              (shareUnitsByMember[split.memberId] ?? 0) +
              toMinorUnits(split.shareAmount, currencyCode);
        }
      }
    }

    final balances = <MemberBalance>[];
    final netUnitsByMember = <String, int>{};
    final memberById = <String, Member>{for (final m in relevantMembers) m.id: m};

    for (final member in relevantMembers) {
      final paid = paidUnitsByMember[member.id] ?? 0;
      final share = shareUnitsByMember[member.id] ?? 0;
      final advGiven = advanceGivenUnitsByMember[member.id] ?? 0;
      final advReceived = advanceReceivedUnitsByMember[member.id] ?? 0;
      final net = (paid - share) + (advGiven - advReceived);
      netUnitsByMember[member.id] = net;

      balances.add(
        MemberBalance(
          member: member,
          totalPaid: fromMinorUnits(paid, currencyCode),
          totalShare: fromMinorUnits(share, currencyCode),
          advanceGiven: fromMinorUnits(advGiven, currencyCode),
          advanceReceived: fromMinorUnits(advReceived, currencyCode),
          netBalance: fromMinorUnits(net, currencyCode),
        ),
      );
    }

    // Sort balances: creditors first (highest net), then debtors (lowest net).
    balances.sort((a, b) => b.netBalance.compareTo(a.netBalance));

    final transfers = savedTransfers ??
        _minimizeTransfers(
          cycleId: cycle.id,
          netUnitsByMember: netUnitsByMember,
          memberById: memberById,
          currencyCode: currencyCode,
        );

    return CycleSettlementReport(
      cycle: cycle,
      totalExpense: fromMinorUnits(totalUnits, currencyCode),
      balances: balances,
      transfers: transfers,
      expenses: expenses,
    );
  }

  static List<SettlementTransfer> _minimizeTransfers({
    required String cycleId,
    required Map<String, int> netUnitsByMember,
    required Map<String, Member> memberById,
    required String currencyCode,
  }) {
    final creditors = <_MemberUnits>[];
    final debtors = <_MemberUnits>[];

    netUnitsByMember.forEach((memberId, net) {
      if (net > 0) {
        creditors.add(_MemberUnits(memberId: memberId, units: net));
      } else if (net < 0) {
        debtors.add(_MemberUnits(memberId: memberId, units: -net));
      }
    });

    creditors.sort((a, b) => b.units.compareTo(a.units));
    debtors.sort((a, b) => b.units.compareTo(a.units));

    final transfers = <SettlementTransfer>[];
    var i = 0;
    var j = 0;

    while (i < debtors.length && j < creditors.length) {
      final debtor = debtors[i];
      final creditor = creditors[j];
      final settledUnits = min(debtor.units, creditor.units);

      if (settledUnits > 0) {
        final fromName = memberById[debtor.memberId]?.name ?? 'Unknown';
        final toName = memberById[creditor.memberId]?.name ?? 'Unknown';
        transfers.add(
          SettlementTransfer(
            id: _uuid.v4(),
            cycleId: cycleId,
            fromMemberId: debtor.memberId,
            toMemberId: creditor.memberId,
            fromMemberName: fromName,
            toMemberName: toName,
            amount: fromMinorUnits(settledUnits, currencyCode),
          ),
        );
      }

      debtor.units -= settledUnits;
      creditor.units -= settledUnits;

      if (debtor.units == 0) i++;
      if (creditor.units == 0) j++;
    }

    return transfers;
  }
}

class _MemberUnits {
  final String memberId;
  int units;

  _MemberUnits({required this.memberId, required this.units});
}
