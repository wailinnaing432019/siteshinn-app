import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/l10n/app_strings.dart';
import '../data/models/account.dart';
import '../data/models/expense.dart';
import '../data/models/member.dart';
import '../data/models/settlement_cycle.dart';
import '../data/models/settlement_summary.dart';
import '../data/repositories/budget_repository.dart';
import '../services/settlement_service.dart';

final repositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository();
});

class AppSettingsState {
  final AppLanguage language;
  final ThemeMode themeMode;
  final String? activeAccountId;
  final bool isLoaded;

  const AppSettingsState({
    this.language = AppLanguage.en,
    this.themeMode = ThemeMode.system,
    this.activeAccountId,
    this.isLoaded = false,
  });

  AppSettingsState copyWith({
    AppLanguage? language,
    ThemeMode? themeMode,
    String? activeAccountId,
    bool clearActiveAccount = false,
    bool? isLoaded,
  }) {
    return AppSettingsState(
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
      activeAccountId:
          clearActiveAccount ? null : (activeAccountId ?? this.activeAccountId),
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

class AppSettingsNotifier extends Notifier<AppSettingsState> {
  static const _langKey = 'app_language';
  static const _themeKey = 'theme_mode';
  static const _accountKey = 'active_account_id';

  @override
  AppSettingsState build() {
    _load();
    return const AppSettingsState();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final langStr = prefs.getString(_langKey) ?? 'en';
    final themeStr = prefs.getString(_themeKey) ?? 'system';
    final accountId = prefs.getString(_accountKey);

    final language = langStr == 'my' ? AppLanguage.my : AppLanguage.en;
    final themeMode = switch (themeStr) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    state = AppSettingsState(
      language: language,
      themeMode: themeMode,
      activeAccountId: accountId,
      isLoaded: true,
    );
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = state.copyWith(language: language);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langKey, language == AppLanguage.my ? 'my' : 'en');
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(_themeKey, value);
  }

  Future<void> setActiveAccountId(String? accountId) async {
    state = state.copyWith(
      activeAccountId: accountId,
      clearActiveAccount: accountId == null,
    );
    final prefs = await SharedPreferences.getInstance();
    if (accountId == null) {
      await prefs.remove(_accountKey);
    } else {
      await prefs.setString(_accountKey, accountId);
    }
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettingsNotifier, AppSettingsState>(
  AppSettingsNotifier.new,
);

final appStringsProvider = Provider<AppStrings>((ref) {
  final language = ref.watch(appSettingsProvider.select((s) => s.language));
  return AppStrings.of(language);
});

class DashboardState {
  final List<Account> accounts;
  final Account? activeAccount;
  final List<Member> members;
  final SettlementCycle? currentCycle;
  final List<Expense> expenses;
  final List<SettlementCycle> settledCycles;
  final CycleSettlementReport? currentReport;
  final bool isLoading;

  const DashboardState({
    this.accounts = const [],
    this.activeAccount,
    this.members = const [],
    this.currentCycle,
    this.expenses = const [],
    this.settledCycles = const [],
    this.currentReport,
    this.isLoading = true,
  });

  List<Member> get activeMembers => members.where((m) => m.isActive).toList();
}

class DashboardNotifier extends AsyncNotifier<DashboardState> {
  BudgetRepository get _repo => ref.read(repositoryProvider);

  @override
  Future<DashboardState> build() async {
    // Wait until SharedPreferences are loaded so we pick the right active account.
    final settings = ref.watch(appSettingsProvider);
    if (!settings.isLoaded) {
      return const DashboardState(isLoading: true);
    }
    return _loadDashboard(settings.activeAccountId);
  }

  Future<DashboardState> _loadDashboard(String? preferredAccountId) async {
    final accounts = await _repo.getAccounts();
    if (accounts.isEmpty) {
      return const DashboardState(
        accounts: [],
        activeAccount: null,
        isLoading: false,
      );
    }

    final activeAccount = accounts.firstWhere(
      (a) => a.id == preferredAccountId,
      orElse: () => accounts.first,
    );

    if (activeAccount.id != preferredAccountId) {
      await ref
          .read(appSettingsProvider.notifier)
          .setActiveAccountId(activeAccount.id);
    }

    final members = await _repo.getMembers(activeAccount.id);
    final currentCycle = await _repo.getOrCreateOpenCycle(activeAccount.id);
    final expenses = await _repo.getExpensesForCycle(currentCycle.id);
    final settledCycles = await _repo.getSettledCycles(activeAccount.id);

    final report = SettlementService.calculateReport(
      cycle: currentCycle,
      allMembers: members,
      expenses: expenses,
      currencyCode: activeAccount.currencyCode,
    );

    return DashboardState(
      accounts: accounts,
      activeAccount: activeAccount,
      members: members,
      currentCycle: currentCycle,
      expenses: expenses,
      settledCycles: settledCycles,
      currentReport: report,
      isLoading: false,
    );
  }

  Future<void> refresh() async {
    final preferredId = ref.read(appSettingsProvider).activeAccountId;
    state = AsyncData(await _loadDashboard(preferredId));
  }

  Future<void> switchAccount(String accountId) async {
    await ref.read(appSettingsProvider.notifier).setActiveAccountId(accountId);
    state = AsyncData(await _loadDashboard(accountId));
  }

  Future<void> createAccount({
    required String name,
    required String currencyCode,
    required List<String> memberNames,
  }) async {
    final account = await _repo.createAccountWithMembers(
      name: name,
      currencyCode: currencyCode,
      memberNames: memberNames,
    );
    await ref.read(appSettingsProvider.notifier).setActiveAccountId(account.id);
    state = AsyncData(await _loadDashboard(account.id));
  }

  Future<void> updateAccount(Account account) async {
    await _repo.updateAccount(account);
    await refresh();
  }

  Future<void> addMember(String name) async {
    final account = state.value?.activeAccount;
    if (account == null) return;
    await _repo.addMember(accountId: account.id, name: name);
    await refresh();
  }

  Future<void> updateMember(Member member) async {
    await _repo.updateMember(member);
    await refresh();
  }

  Future<void> saveExpense({
    String? existingExpenseId,
    required String paidByMemberId,
    required String title,
    required ExpenseCategory category,
    required double amount,
    required DateTime expenseDate,
    required List<String> participantIds,
  }) async {
    final current = state.value;
    final account = current?.activeAccount;
    final cycle = current?.currentCycle;
    if (account == null || cycle == null) return;

    await _repo.saveExpense(
      existingExpenseId: existingExpenseId,
      accountId: account.id,
      cycleId: cycle.id,
      paidByMemberId: paidByMemberId,
      title: title,
      category: category,
      amount: amount,
      expenseDate: expenseDate,
      participantIds: participantIds,
      currencyCode: account.currencyCode,
    );
    await refresh();
  }

  Future<void> deleteExpense(String expenseId) async {
    await _repo.deleteExpense(expenseId);
    await refresh();
  }

  Future<void> closeCurrentCycle(String settledTitle) async {
    final current = state.value;
    final report = current?.currentReport;
    if (report == null) return;

    await _repo.closeCycleAndStartNext(
      cycle: report.cycle,
      settledTitle: settledTitle,
      transfers: report.transfers,
    );
    await refresh();
  }

  Future<CycleSettlementReport> loadHistoricalReport(
    SettlementCycle cycle,
  ) async {
    final current = state.value!;
    final account = current.activeAccount!;
    final members = current.members;
    final memberById = {for (final m in members) m.id: m};

    final expenses = await _repo.getExpensesForCycle(cycle.id);
    final savedTransfers = await _repo.getTransfersForCycle(
      cycleId: cycle.id,
      memberById: memberById,
    );

    return SettlementService.calculateReport(
      cycle: cycle,
      allMembers: members,
      expenses: expenses,
      currencyCode: account.currencyCode,
      savedTransfers: savedTransfers,
    );
  }
}

final dashboardProvider =
    AsyncNotifierProvider<DashboardNotifier, DashboardState>(
  DashboardNotifier.new,
);
