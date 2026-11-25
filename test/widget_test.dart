import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:site_shinn/app.dart';
import 'package:site_shinn/core/l10n/app_strings.dart';
import 'package:site_shinn/data/models/account.dart';
import 'package:site_shinn/data/models/expense.dart';
import 'package:site_shinn/data/models/member.dart';
import 'package:site_shinn/data/models/settlement_cycle.dart';
import 'package:site_shinn/presentation/screens/settlement_screen.dart';
import 'package:site_shinn/providers/app_providers.dart';
import 'package:site_shinn/services/settlement_service.dart';

void main() {
  testWidgets('Shows onboarding screen with 5 member fields when empty',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProvider.overrideWith(_EmptyDashboardNotifier.new),
        ],
        child: const SiteShinnApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Welcome to SiteShinn'), findsOneWidget);
    expect(find.text('Member Name 1'), findsOneWidget);
    expect(find.text('Member Name 5'), findsOneWidget);
    expect(find.text('Create Group & Start'), findsOneWidget);
  });

  testWidgets('Settle Up asks user for cycle name without Cycle 1 default',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProvider.overrideWith(_PopulatedDashboardNotifier.new),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SettlementScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cycle 1'), findsNothing);
    expect(find.text('Current Cycle'), findsOneWidget);

    final settleBtn = find.text('Settle & Close Cycle');
    await tester.scrollUntilVisible(settleBtn, 300.0);
    await tester.tap(settleBtn);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings(AppLanguage.en).cycleNameLabel), findsOneWidget);
    expect(find.text('Cycle 1'), findsNothing);
  });
}

class _EmptyDashboardNotifier extends DashboardNotifier {
  @override
  Future<DashboardState> build() async {
    return const DashboardState(accounts: [], isLoading: false);
  }
}

class _PopulatedDashboardNotifier extends DashboardNotifier {
  @override
  Future<DashboardState> build() async {
    final now = DateTime(2026, 11, 25);
    final account = Account(
      id: 'acc1',
      name: 'Room 5',
      currencyCode: 'MMK',
      createdAt: now,
    );
    final members = [
      Member(id: 'm1', accountId: 'acc1', name: 'Aung', createdAt: now),
      Member(id: 'm2', accountId: 'acc1', name: 'Kyaw', createdAt: now),
    ];
    final cycle = SettlementCycle(
      id: 'c1',
      accountId: 'acc1',
      title: '',
      startDate: now,
    );
    final expenses = [
      Expense(
        id: 'e1',
        accountId: 'acc1',
        cycleId: 'c1',
        paidByMemberId: 'm1',
        title: 'Groceries',
        category: ExpenseCategory.food,
        amount: 10000,
        expenseDate: now,
        createdAt: now,
        splits: SettlementService.buildEqualSplits(
          expenseId: 'e1',
          amount: 10000,
          participantIds: ['m1', 'm2'],
          currencyCode: 'MMK',
        ),
      ),
    ];
    final report = SettlementService.calculateReport(
      cycle: cycle,
      allMembers: members,
      expenses: expenses,
      currencyCode: 'MMK',
    );
    return DashboardState(
      accounts: [account],
      activeAccount: account,
      members: members,
      currentCycle: cycle,
      expenses: expenses,
      currentReport: report,
      isLoading: false,
    );
  }
}
