import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:site_shinn/app.dart';
import 'package:site_shinn/presentation/screens/user_guide_screen.dart';
import 'package:site_shinn/presentation/widgets/app_update_dialog.dart';
import 'package:site_shinn/presentation/widgets/export_sheet.dart';
import 'package:site_shinn/services/app_update_service.dart';
import 'package:site_shinn/services/export_file_opener.dart';
import 'package:site_shinn/services/pdf_export_service.dart';
import 'package:site_shinn/core/l10n/app_strings.dart';
import 'package:site_shinn/core/utils/error_formatter.dart';
import 'package:site_shinn/data/models/account.dart';
import 'package:site_shinn/data/models/expense.dart';
import 'package:site_shinn/data/models/member.dart';
import 'package:site_shinn/data/models/settlement_cycle.dart';
import 'package:site_shinn/data/models/settlement_summary.dart';
import 'package:site_shinn/data/repositories/cloud_budget_repository.dart';
import 'package:site_shinn/presentation/screens/auth_screen.dart';
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
    expect(find.text('Create Account & Start'), findsOneWidget);
  });

  testWidgets('AccountSetupForm switches to Personal Wallet with Opening Balance',
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

    await tester.tap(find.text('Personal Wallet'));
    await tester.pumpAndSettle();

    expect(find.text('Opening Balance'), findsOneWidget);
    expect(find.text('Member Name 1'), findsNothing);
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

  testWidgets('Export Excel shows both Share File and Save to Device',
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

    await tester.tap(find.text('Export Excel'));
    await tester.pumpAndSettle();

    expect(find.text('Share File'), findsOneWidget);
    expect(find.text('Save to Device'), findsOneWidget);
  });

  testWidgets('History detail shows expenses list below Member Breakdown',
      (tester) async {
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
      title: 'Week 1',
      startDate: now,
      endDate: now,
      isSettled: true,
    );
    final expenses = [
      Expense(
        id: 'e1',
        accountId: 'acc1',
        cycleId: 'c1',
        paidByMemberId: 'm1',
        title: 'Market Groceries',
        category: ExpenseCategory.food,
        amount: 12000,
        expenseDate: now,
        createdAt: now,
        splits: SettlementService.buildEqualSplits(
          expenseId: 'e1',
          amount: 12000,
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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CycleReportView(
            account: account,
            report: report,
            allMembers: members,
            strings: const AppStrings(AppLanguage.en),
            isOpenCycle: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final expensesHeader = find.text('Expenses (1)');
    await tester.scrollUntilVisible(expensesHeader, 300.0);
    expect(expensesHeader, findsOneWidget);
    expect(find.text('Market Groceries'), findsOneWidget);
  });

  testWidgets('Toggling reminder stays on Accounts tab and Home switcher works',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProvider.overrideWith(_MultiAccountDashboardNotifier.new),
        ],
        child: const SiteShinnApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Tapping account title on Ledger/Expenses tab opens Account Switcher sheet.
    await tester.tap(find.text('Room 5'));
    await tester.pumpAndSettle();
    expect(find.text('Switch Account'), findsOneWidget);
    expect(find.text('My Wallet'), findsOneWidget);

    // Dismiss switcher sheet.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // Navigate to Accounts tab.
    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();
    expect(find.text('Accounts & Settings'), findsOneWidget);

    // Toggle alarm switch ON -> must stay on Accounts tab; Stop button is hidden initially.
    await tester.scrollUntilVisible(
      find.text('Daily Reminder & Alarm'),
      200.0,
    );
    final alarmSwitch = find.byType(Switch).first;
    await tester.ensureVisible(alarmSwitch);
    await tester.pumpAndSettle();
    await tester.tap(alarmSwitch);
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(alarmSwitch).value, isTrue);

    expect(find.text('Accounts & Settings'), findsOneWidget);
    expect(find.text('Add Alarm'), findsOneWidget);
    expect(find.text('Alarm Sound'), findsOneWidget);
    expect(find.text('Stop'), findsNothing);

    // Tapping Test Sound Now temporarily reveals Stop button.
    final testBtn = find.text('Test Sound Now');
    await tester.scrollUntilVisible(testBtn, 300.0);
    await tester.tap(testBtn);
    await tester.pump();
    expect(find.text('Stop'), findsOneWidget);

    // Tapping Stop hides Stop button again and clears the preview timer.
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
    expect(find.text('Stop'), findsNothing);
  });

  testWidgets('AuthScreen toggles Sign Up mode and offline fallback works',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AuthScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Continue Offline (Local Only)'), findsOneWidget);

    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();
    expect(find.text('Your Name'), findsOneWidget);
  });

  testWidgets('Closed CycleReportView invokes onToggleTransferPaid when tapped',
      (tester) async {
    final now = DateTime(2026, 11, 25);
    final account = Account(
      id: 'acc1',
      name: 'Room 5',
      currencyCode: 'MMK',
      createdAt: now,
    );
    final m1 = Member(id: 'm1', accountId: 'acc1', name: 'Aung', createdAt: now);
    final m2 = Member(id: 'm2', accountId: 'acc1', name: 'Kyaw', createdAt: now);
    final cycle = SettlementCycle(
      id: 'c1',
      accountId: 'acc1',
      title: 'Nov 2026',
      startDate: now,
      endDate: now,
      isSettled: true,
    );
    final report = CycleSettlementReport(
      cycle: cycle,
      totalExpense: 10000,
      balances: [
        MemberBalance(
          member: m1,
          totalPaid: 10000,
          totalShare: 5000,
          netBalance: 5000,
        ),
        MemberBalance(
          member: m2,
          totalPaid: 0,
          totalShare: 5000,
          netBalance: -5000,
        ),
      ],
      transfers: const [
        SettlementTransfer(
          id: 't1',
          cycleId: 'c1',
          fromMemberId: 'm2',
          toMemberId: 'm1',
          fromMemberName: 'Kyaw',
          toMemberName: 'Aung',
          amount: 5000,
          isPaid: false,
        ),
      ],
      expenses: const [],
    );

    String? toggledId;
    bool? toggledPaid;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CycleReportView(
            account: account,
            report: report,
            allMembers: [m1, m2],
            strings: const AppStrings(AppLanguage.en),
            isOpenCycle: false,
            onToggleTransferPaid: (id, isPaid) async {
              toggledId = id;
              toggledPaid = isPaid;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Tap to mark paid'));
    await tester.pumpAndSettle();

    expect(toggledId, 't1');
    expect(toggledPaid, isTrue);
  });

  test('CloudBudgetRepository.migratedIdForUser isolates local IDs per user',
      () {
    const userA = '11111111-1111-4111-8111-111111111111';
    const userB = '22222222-2222-4222-8222-222222222222';
    const localId = '33333333-3333-4333-8333-333333333333';

    final a1 = CloudBudgetRepository.migratedIdForUser(userA, localId);
    final a2 = CloudBudgetRepository.migratedIdForUser(userA, localId);
    final b1 = CloudBudgetRepository.migratedIdForUser(userB, localId);

    expect(a1, a2);
    expect(a1, isNot(localId));
    expect(a1, isNot(b1));
  });

  test('AppErrorFormatter detects offline errors cleanly', () {
    const stringsEn = AppStrings(AppLanguage.en);
    const stringsMy = AppStrings(AppLanguage.my);
    const socketErr = SocketException('Failed host lookup');

    expect(AppErrorFormatter.isOfflineError(socketErr), isTrue);
    expect(
      AppErrorFormatter.formatError(socketErr, stringsEn),
      stringsEn.offlineNetworkError,
    );
    expect(
      AppErrorFormatter.formatError(socketErr, stringsMy),
      stringsMy.offlineNetworkError,
    );
  });

  testWidgets('Tapping transfer card expands to show full member names',
      (tester) async {
    final now = DateTime(2026, 11, 25);
    final account = Account(
      id: 'acc1',
      name: 'Room 5',
      currencyCode: 'MMK',
      createdAt: now,
    );
    final m1 = Member(
      id: 'm1',
      accountId: 'acc1',
      name: 'Wai Linn Naing',
      createdAt: now,
    );
    final m2 = Member(
      id: 'm2',
      accountId: 'acc1',
      name: 'Wai Linn Kyaw',
      createdAt: now,
    );
    final cycle = SettlementCycle(
      id: 'c1',
      accountId: 'acc1',
      title: '',
      startDate: now,
    );
    final report = CycleSettlementReport(
      cycle: cycle,
      totalExpense: 5260,
      balances: [
        MemberBalance(
          member: m1,
          totalPaid: 5260,
          totalShare: 2630,
          netBalance: 2630,
        ),
        MemberBalance(
          member: m2,
          totalPaid: 0,
          totalShare: 2630,
          netBalance: -2630,
        ),
      ],
      transfers: const [
        SettlementTransfer(
          id: 't1',
          cycleId: 'c1',
          fromMemberId: 'm2',
          toMemberId: 'm1',
          fromMemberName: 'Wai Linn Kyaw',
          toMemberName: 'Wai Linn Naing',
          amount: 2630,
        ),
      ],
      expenses: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CycleReportView(
            account: account,
            report: report,
            allMembers: [m1, m2],
            strings: const AppStrings(AppLanguage.en),
            isOpenCycle: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.subdirectory_arrow_right_rounded), findsNothing);

    await tester.tap(find.text('Wai Linn Kyaw').first);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.subdirectory_arrow_right_rounded), findsOneWidget);
    expect(find.text('Wai Linn Kyaw'), findsWidgets);
    expect(find.text('Wai Linn Naing'), findsWidgets);
  });

  test('PdfExportService.buildCycleHtml renders Burmese text and escapes HTML',
      () {
    final now = DateTime(2026, 11, 25);
    final account = Account(
      id: 'acc1',
      name: 'အခန်း ၅ & Friends',
      currencyCode: 'MMK',
      createdAt: now,
    );
    final m1 = Member(id: 'm1', accountId: 'acc1', name: 'မောင်မောင်', createdAt: now);
    final m2 = Member(id: 'm2', accountId: 'acc1', name: 'အောင်အောင်', createdAt: now);
    final cycle = SettlementCycle(
      id: 'c1',
      accountId: 'acc1',
      title: 'နိုဝင်ဘာ',
      startDate: now,
      isSettled: true,
    );
    final report = CycleSettlementReport(
      cycle: cycle,
      totalExpense: 10000,
      balances: [
        MemberBalance(
          member: m1,
          totalPaid: 10000,
          totalShare: 5000,
          netBalance: 5000,
        ),
        MemberBalance(
          member: m2,
          totalPaid: 0,
          totalShare: 5000,
          netBalance: -5000,
        ),
      ],
      transfers: const [
        SettlementTransfer(
          id: 't1',
          cycleId: 'c1',
          fromMemberId: 'm2',
          toMemberId: 'm1',
          fromMemberName: 'အောင်အောင်',
          toMemberName: 'မောင်မောင်',
          amount: 5000,
          isPaid: true,
        ),
      ],
      expenses: const [],
    );

    final html = PdfExportService.buildCycleHtml(
      account: account,
      report: report,
      allMembers: [m1, m2],
      strings: const AppStrings(AppLanguage.my),
    );

    expect(html, contains('lang="my"'));
    expect(html, contains('အခန်း ၅ &amp; Friends'));
    expect(html, contains('အောင်အောင်'));
    expect(html, contains('မောင်မောင်'));
    expect(html, contains('ပေးပြီး'));

    final payload = PdfExportService.buildCyclePdfPayload(
      account: account,
      report: report,
      allMembers: [m1, m2],
      strings: const AppStrings(AppLanguage.en),
    );
    expect(payload['subtitle'], isNot(contains('Now')));
  });

  testWidgets('Save to Device shows SnackBar with Open action button',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showExportOptionsSheet(
                context: context,
                strings: const AppStrings(AppLanguage.en),
                title: 'Export PDF',
                onShare: () async {},
                onSaveToDevice: () async => const SavedExportResult(
                  uriOrPath: 'content://downloads/test.pdf',
                  mimeType: 'application/pdf',
                  fileName: 'test_report.pdf',
                ),
              ),
              child: const Text('Trigger Export'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Trigger Export'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save to Device'));
    await tester.pumpAndSettle();

    expect(find.textContaining('test_report.pdf'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
  });

  test('AppErrorFormatter.formatErrorAsync surfaces VPN hint when network is up',
      () async {
    const stringsEn = AppStrings(AppLanguage.en);
    final msg = await AppErrorFormatter.formatErrorAsync(
      const SocketException('Failed host lookup'),
      stringsEn,
    );
    expect(msg, stringsEn.serverUnreachableError);
  });

  test('AppUpdateService.resolveApkUrl matches supported ABI then falls back',
      () {
    final data = {
      'apk_url': 'https://example.com/fallback.apk',
      'apk_urls': {
        'arm64-v8a': 'https://example.com/arm64.apk',
        'armeabi-v7a': 'https://example.com/arm32.apk',
      },
    };
    expect(
      AppUpdateService.resolveApkUrl(data, ['arm64-v8a', 'armeabi-v7a']),
      'https://example.com/arm64.apk',
    );
    expect(
      AppUpdateService.resolveApkUrl(data, ['x86_64']),
      'https://example.com/fallback.apk',
    );
  });

  testWidgets('UserGuideScreen renders bilingual sections and switches language',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: UserGuideScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('User Guide'), findsOneWidget);
    expect(find.textContaining('Group Expense Splits'), findsOneWidget);

    await tester.tap(find.text('မြန်မာ'));
    await tester.pumpAndSettle();

    expect(find.textContaining('အသုံးပြုနည်း'), findsWidgets);
  });

  testWidgets('AppUpdateDialog shows version jump, release notes, and Update Now',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppUpdateDialog(
            info: AppUpdateInfo(
              currentVersion: '2.0.0',
              currentBuild: 2,
              latestVersion: '2.0.1',
              latestBuild: 3,
              apkUrl: 'https://example.com/app.apk',
              releaseNotes: 'Improved PDF export',
            ),
            strings: AppStrings(AppLanguage.en),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('App Update Available'), findsOneWidget);
    expect(find.textContaining('v2.0.0'), findsOneWidget);
    expect(find.textContaining('v2.0.1'), findsOneWidget);
    expect(find.text('Improved PDF export'), findsOneWidget);
    expect(find.text('Update Now'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
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

class _MultiAccountDashboardNotifier extends DashboardNotifier {
  @override
  Future<DashboardState> build() async {
    ref.watch(appSettingsProvider.select((s) => s.isLoaded));
    ref.watch(appSettingsProvider.select((s) => s.activeAccountId));

    final now = DateTime(2026, 11, 25);
    final groupAcc = Account(
      id: 'acc1',
      name: 'Room 5',
      currencyCode: 'MMK',
      createdAt: now,
    );
    final personalAcc = Account(
      id: 'acc2',
      name: 'My Wallet',
      currencyCode: 'MMK',
      accountType: AccountType.personal,
      openingBalance: 50000,
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
    final report = SettlementService.calculateReport(
      cycle: cycle,
      allMembers: members,
      expenses: const [],
      currencyCode: 'MMK',
    );
    return DashboardState(
      accounts: [groupAcc, personalAcc],
      activeAccount: groupAcc,
      members: members,
      currentCycle: cycle,
      expenses: const [],
      currentReport: report,
      isLoading: false,
    );
  }
}
