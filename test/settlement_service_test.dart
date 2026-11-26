import 'package:flutter_test/flutter_test.dart';
import 'package:site_shinn/data/models/account.dart';
import 'package:site_shinn/data/models/expense.dart';
import 'package:site_shinn/data/models/member.dart';
import 'package:site_shinn/data/models/personal_summary.dart';
import 'package:site_shinn/data/models/settlement_cycle.dart';
import 'package:site_shinn/services/settlement_service.dart';

void main() {
  final now = DateTime(2026, 11, 25);

  List<Member> makeMembers(List<String> names) {
    return List.generate(
      names.length,
      (i) => Member(
        id: 'm$i',
        accountId: 'acc1',
        name: names[i],
        createdAt: now,
      ),
    );
  }

  SettlementCycle makeCycle() {
    return SettlementCycle(
      id: 'c1',
      accountId: 'acc1',
      title: 'Cycle 1',
      startDate: now,
    );
  }

  group('SettlementService.buildEqualSplits', () {
    test('distributes MMK remainder strictly so total matches amount', () {
      final splits = SettlementService.buildEqualSplits(
        expenseId: 'e1',
        amount: 10000,
        participantIds: ['m0', 'm1', 'm2'],
        currencyCode: 'MMK',
      );

      expect(splits.length, 3);
      final sum = splits.fold<double>(0, (acc, s) => acc + s.shareAmount);
      expect(sum, 10000);
      expect(splits[0].shareAmount, 3334);
      expect(splits[1].shareAmount, 3333);
      expect(splits[2].shareAmount, 3333);
    });

    test('handles 2-decimal currency USD cleanly', () {
      final splits = SettlementService.buildEqualSplits(
        expenseId: 'e2',
        amount: 10.00,
        participantIds: ['m0', 'm1', 'm2'],
        currencyCode: 'USD',
      );

      final sum = splits.fold<double>(0, (acc, s) => acc + s.shareAmount);
      expect(sum, closeTo(10.00, 0.0001));
      expect(splits[0].shareAmount, 3.34);
      expect(splits[1].shareAmount, 3.33);
      expect(splits[2].shareAmount, 3.33);
    });
  });

  group('SettlementService.calculateReport', () {
    test('calculates 5-roommate weekly settlement accurately', () {
      final members = makeMembers(['Aung', 'Kyaw', 'Mg Mg', 'Su', 'Hla']);
      final cycle = makeCycle();

      // Aung paid 25,000 (split among all 5 -> 5,000 each)
      // Kyaw paid 15,000 (split among all 5 -> 3,000 each)
      // Total = 40,000; Each member's share = 8,000.
      // Net: Aung +17,000, Kyaw +7,000, Mg Mg -8,000, Su -8,000, Hla -8,000
      final e1Splits = SettlementService.buildEqualSplits(
        expenseId: 'e1',
        amount: 25000,
        participantIds: members.map((m) => m.id).toList(),
        currencyCode: 'MMK',
      );
      final e2Splits = SettlementService.buildEqualSplits(
        expenseId: 'e2',
        amount: 15000,
        participantIds: members.map((m) => m.id).toList(),
        currencyCode: 'MMK',
      );

      final expenses = [
        Expense(
          id: 'e1',
          accountId: 'acc1',
          cycleId: 'c1',
          paidByMemberId: 'm0',
          title: 'Groceries',
          category: ExpenseCategory.food,
          amount: 25000,
          expenseDate: now,
          createdAt: now,
          splits: e1Splits,
        ),
        Expense(
          id: 'e2',
          accountId: 'acc1',
          cycleId: 'c1',
          paidByMemberId: 'm1',
          title: 'Cooking Gas',
          category: ExpenseCategory.cooking,
          amount: 15000,
          expenseDate: now,
          createdAt: now,
          splits: e2Splits,
        ),
      ];

      final report = SettlementService.calculateReport(
        cycle: cycle,
        allMembers: members,
        expenses: expenses,
        currencyCode: 'MMK',
      );

      expect(report.totalExpense, 40000);
      final netSum = report.balances.fold<double>(
        0,
        (acc, b) => acc + b.netBalance,
      );
      expect(netSum, 0);

      final transferTotal = report.transfers.fold<double>(
        0,
        (acc, t) => acc + t.amount,
      );
      expect(transferTotal, 24000);
      // 3 debtors paying 2 creditors -> at most 4 transfers.
      expect(report.transfers.length, lessThanOrEqualTo(4));

      // Verify applying transfers zeroes out all balances.
      final simulated = {
        for (final b in report.balances) b.member.id: b.netBalance,
      };
      for (final t in report.transfers) {
        simulated[t.fromMemberId] = (simulated[t.fromMemberId] ?? 0) + t.amount;
        simulated[t.toMemberId] = (simulated[t.toMemberId] ?? 0) - t.amount;
      }
      for (final value in simulated.values) {
        expect(value, 0);
      }
    });

    test('handles partial participant splits and inactive members in history', () {
      final members = [
        Member(id: 'm0', accountId: 'acc1', name: 'Aung', createdAt: now),
        Member(
          id: 'm1',
          accountId: 'acc1',
          name: 'Kyaw',
          isActive: false,
          createdAt: now,
        ),
        Member(id: 'm2', accountId: 'acc1', name: 'Su', createdAt: now),
      ];
      final cycle = makeCycle();

      // Only Aung and inactive Kyaw shared a 10,000 meal paid by Aung.
      final splits = SettlementService.buildEqualSplits(
        expenseId: 'e1',
        amount: 10000,
        participantIds: ['m0', 'm1'],
        currencyCode: 'MMK',
      );

      final report = SettlementService.calculateReport(
        cycle: cycle,
        allMembers: members,
        expenses: [
          Expense(
            id: 'e1',
            accountId: 'acc1',
            cycleId: 'c1',
            paidByMemberId: 'm0',
            title: 'Lunch',
            category: ExpenseCategory.food,
            amount: 10000,
            expenseDate: now,
            createdAt: now,
            splits: splits,
          ),
        ],
        currencyCode: 'MMK',
      );

      expect(report.transfers.length, 1);
      expect(report.transfers.first.fromMemberName, 'Kyaw');
      expect(report.transfers.first.toMemberName, 'Aung');
      expect(report.transfers.first.amount, 5000);
    });
  });

  group('PersonalLedgerSummary.compute', () {
    test('calculates opening balance + income - expense and filters by date range', () {
      final account = Account(
        id: 'p1',
        name: 'My Wallet',
        currencyCode: 'MMK',
        accountType: AccountType.personal,
        openingBalance: 100000,
        createdAt: now,
      );
      final txs = [
        Expense(
          id: 't1',
          accountId: 'p1',
          cycleId: 'c1',
          txType: TransactionType.income,
          title: 'Salary',
          category: ExpenseCategory.salary,
          amount: 500000,
          expenseDate: DateTime(2026, 11, 1),
          createdAt: now,
        ),
        Expense(
          id: 't2',
          accountId: 'p1',
          cycleId: 'c1',
          txType: TransactionType.expense,
          title: 'Lunch',
          category: ExpenseCategory.food,
          amount: 25000,
          expenseDate: DateTime(2026, 11, 15),
          createdAt: now,
        ),
        Expense(
          id: 't3',
          accountId: 'p1',
          cycleId: 'c1',
          txType: TransactionType.expense,
          title: 'October Bus',
          category: ExpenseCategory.transport,
          amount: 15000,
          expenseDate: DateTime(2026, 10, 20),
          createdAt: now,
        ),
      ];

      final all = PersonalLedgerSummary.compute(
        account: account,
        allTransactions: txs,
      );
      expect(all.openingBalance, 100000);
      expect(all.totalIncome, 500000);
      expect(all.totalExpense, 40000);
      expect(all.currentBalance, 560000);
      expect(all.filteredTransactions.length, 3);

      final novOnly = PersonalLedgerSummary.compute(
        account: account,
        allTransactions: txs,
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 30),
      );
      expect(novOnly.currentBalance, 560000);
      expect(novOnly.periodIncome, 500000);
      expect(novOnly.periodExpense, 25000);
      expect(novOnly.filteredTransactions.length, 2);
    });
  });
}
