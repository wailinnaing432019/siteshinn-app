import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/l10n/app_strings.dart';
import '../data/models/account.dart';
import '../data/models/expense.dart';
import '../data/models/member.dart';
import '../data/models/personal_summary.dart';
import '../data/models/reminder_alarm.dart';
import '../data/models/settlement_cycle.dart';
import '../data/models/settlement_summary.dart';
import '../data/repositories/budget_repository.dart';
import '../services/reminder_service.dart';
import '../services/settlement_service.dart';

final repositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository();
});

class AppSettingsState {
  final AppLanguage language;
  final ThemeMode themeMode;
  final String? activeAccountId;
  final List<ReminderAlarm> alarms;
  final bool alarmMode;
  final String? customAlarmPath;
  final String? customAlarmName;
  final bool isLoaded;

  const AppSettingsState({
    this.language = AppLanguage.en,
    this.themeMode = ThemeMode.system,
    this.activeAccountId,
    this.alarms = const [
      ReminderAlarm(id: 1001, hour: 19, minute: 0, enabled: false),
    ],
    this.alarmMode = true,
    this.customAlarmPath,
    this.customAlarmName,
    this.isLoaded = false,
  });

  bool get hasAnyEnabledAlarm => alarms.any((a) => a.enabled);

  AppSettingsState copyWith({
    AppLanguage? language,
    ThemeMode? themeMode,
    String? activeAccountId,
    bool clearActiveAccount = false,
    List<ReminderAlarm>? alarms,
    bool? alarmMode,
    String? customAlarmPath,
    String? customAlarmName,
    bool clearCustomAlarm = false,
    bool? isLoaded,
  }) {
    return AppSettingsState(
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
      activeAccountId:
          clearActiveAccount ? null : (activeAccountId ?? this.activeAccountId),
      alarms: alarms ?? this.alarms,
      alarmMode: alarmMode ?? this.alarmMode,
      customAlarmPath: clearCustomAlarm
          ? null
          : (customAlarmPath ?? this.customAlarmPath),
      customAlarmName: clearCustomAlarm
          ? null
          : (customAlarmName ?? this.customAlarmName),
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

class AppSettingsNotifier extends Notifier<AppSettingsState> {
  static const _langKey = 'app_language';
  static const _themeKey = 'theme_mode';
  static const _accountKey = 'active_account_id';
  static const _alarmsJsonKey = 'reminder_alarms_json';
  static const _reminderEnabledKey = 'reminder_enabled';
  static const _reminderHourKey = 'reminder_hour';
  static const _reminderMinuteKey = 'reminder_minute';
  static const _alarmModeKey = 'reminder_alarm_mode';
  static const _customAlarmPathKey = 'custom_alarm_path';
  static const _customAlarmNameKey = 'custom_alarm_name';

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
    final alarmMode = prefs.getBool(_alarmModeKey) ?? true;
    final customAlarmPath = prefs.getString(_customAlarmPathKey);
    final customAlarmName = prefs.getString(_customAlarmNameKey);

    List<ReminderAlarm> alarms;
    final rawAlarms = prefs.getString(_alarmsJsonKey);
    if (rawAlarms != null && rawAlarms.isNotEmpty) {
      alarms = ReminderAlarm.decodeList(rawAlarms);
    } else {
      final legacyEnabled = prefs.getBool(_reminderEnabledKey) ?? false;
      final legacyHour = prefs.getInt(_reminderHourKey) ?? 19;
      final legacyMinute = prefs.getInt(_reminderMinuteKey) ?? 0;
      alarms = [
        ReminderAlarm(
          id: 1001,
          hour: legacyHour,
          minute: legacyMinute,
          enabled: legacyEnabled,
        ),
      ];
    }

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
      alarms: alarms,
      alarmMode: alarmMode,
      customAlarmPath: customAlarmPath,
      customAlarmName: customAlarmName,
      isLoaded: true,
    );

    if (alarms.any((a) => a.enabled)) {
      await ReminderService.instance.syncDailyReminders(
        alarms: alarms,
        alarmMode: alarmMode,
        customAudioPath: customAlarmPath,
        strings: AppStrings.of(language),
      );
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = state.copyWith(language: language);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langKey, language == AppLanguage.my ? 'my' : 'en');
    if (state.hasAnyEnabledAlarm) {
      await _syncReminder();
    }
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

  Future<void> _saveAlarmsAndSync(List<ReminderAlarm> nextAlarms) async {
    state = state.copyWith(alarms: nextAlarms);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_alarmsJsonKey, ReminderAlarm.encodeList(nextAlarms));
    if (nextAlarms.any((a) => a.enabled)) {
      await ReminderService.instance.requestPermissions();
    }
    await _syncReminder();
  }

  Future<void> addAlarm({
    required int hour,
    required int minute,
  }) async {
    final maxId = state.alarms.fold<int>(
      1000,
      (prev, a) => a.id > prev ? a.id : prev,
    );
    final next = [
      ...state.alarms,
      ReminderAlarm(
        id: maxId + 1,
        hour: hour,
        minute: minute,
        enabled: true,
      ),
    ];
    await _saveAlarmsAndSync(next);
  }

  Future<void> toggleAlarm(int id, bool enabled) async {
    final next = state.alarms
        .map((a) => a.id == id ? a.copyWith(enabled: enabled) : a)
        .toList();
    await _saveAlarmsAndSync(next);
  }

  Future<void> updateAlarmTime(int id, int hour, int minute) async {
    final next = state.alarms
        .map(
          (a) => a.id == id
              ? a.copyWith(hour: hour, minute: minute, enabled: true)
              : a,
        )
        .toList();
    await _saveAlarmsAndSync(next);
  }

  Future<void> deleteAlarm(int id) async {
    final next = state.alarms.where((a) => a.id != id).toList();
    await _saveAlarmsAndSync(next);
  }

  Future<void> setAlarmMode(bool alarmMode) async {
    state = state.copyWith(alarmMode: alarmMode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_alarmModeKey, alarmMode);
    await _syncReminder();
  }

  Future<void> setCustomAlarmSong({
    required String path,
    required String name,
  }) async {
    state = state.copyWith(customAlarmPath: path, customAlarmName: name);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customAlarmPathKey, path);
    await prefs.setString(_customAlarmNameKey, name);
    if (state.hasAnyEnabledAlarm) {
      await _syncReminder();
    }
  }

  Future<void> clearCustomAlarmSong() async {
    final oldPath = state.customAlarmPath;
    state = state.copyWith(clearCustomAlarm: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_customAlarmPathKey);
    await prefs.remove(_customAlarmNameKey);
    await ReminderService.instance.deleteCustomAlarmFile(oldPath);
    if (state.hasAnyEnabledAlarm) {
      await _syncReminder();
    }
  }

  Future<void> _syncReminder() async {
    await ReminderService.instance.syncDailyReminders(
      alarms: state.alarms,
      alarmMode: state.alarmMode,
      customAudioPath: state.customAlarmPath,
      strings: AppStrings.of(state.language),
    );
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

class PersonalDateRangeNotifier extends Notifier<DateTimeRange?> {
  static DateTimeRange currentMonthRange() {
    final now = DateTime.now();
    return DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0),
    );
  }

  @override
  DateTimeRange? build() => currentMonthRange();

  void setRange(DateTimeRange? range) => state = range;

  void setThisMonth() => state = currentMonthRange();

  void setLast7Days() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    state = DateTimeRange(
      start: today.subtract(const Duration(days: 6)),
      end: today,
    );
  }

  void setAllTime() => state = null;
}

final personalDateRangeProvider =
    NotifierProvider<PersonalDateRangeNotifier, DateTimeRange?>(
  PersonalDateRangeNotifier.new,
);

class DashboardState {
  final List<Account> accounts;
  final Account? activeAccount;
  final List<Member> members;
  final SettlementCycle? currentCycle;
  final List<Expense> expenses;
  final List<SettlementCycle> settledCycles;
  final CycleSettlementReport? currentReport;
  final PersonalLedgerSummary? personalSummary;
  final bool isLoading;

  const DashboardState({
    this.accounts = const [],
    this.activeAccount,
    this.members = const [],
    this.currentCycle,
    this.expenses = const [],
    this.settledCycles = const [],
    this.currentReport,
    this.personalSummary,
    this.isLoading = true,
  });

  List<Member> get activeMembers => members.where((m) => m.isActive).toList();
}

class DashboardNotifier extends AsyncNotifier<DashboardState> {
  BudgetRepository get _repo => ref.read(repositoryProvider);

  @override
  Future<DashboardState> build() async {
    // Only watch isLoaded & activeAccountId so toggling reminder, language, or
    // theme settings never reloads Dashboard or resets the current tab index.
    final isLoaded = ref.watch(appSettingsProvider.select((s) => s.isLoaded));
    final activeAccountId =
        ref.watch(appSettingsProvider.select((s) => s.activeAccountId));
    if (!isLoaded) {
      return const DashboardState(isLoading: true);
    }
    return _loadDashboard(activeAccountId);
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

    final currentCycle = await _repo.getOrCreateOpenCycle(activeAccount.id);

    if (activeAccount.isPersonal) {
      final transactions = await _repo.getTransactionsForAccount(activeAccount.id);
      final personalSummary = PersonalLedgerSummary.compute(
        account: activeAccount,
        allTransactions: transactions,
      );
      return DashboardState(
        accounts: accounts,
        activeAccount: activeAccount,
        members: const [],
        currentCycle: currentCycle,
        expenses: transactions,
        settledCycles: const [],
        currentReport: null,
        personalSummary: personalSummary,
        isLoading: false,
      );
    }

    final members = await _repo.getMembers(activeAccount.id);
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
      personalSummary: null,
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
    AccountType accountType = AccountType.group,
    double openingBalance = 0,
    List<String> memberNames = const [],
  }) async {
    final account = await _repo.createAccount(
      name: name,
      currencyCode: currencyCode,
      accountType: accountType,
      openingBalance: openingBalance,
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
    if (account == null || account.isPersonal) return;
    await _repo.addMember(accountId: account.id, name: name);
    await refresh();
  }

  Future<void> updateMember(Member member) async {
    await _repo.updateMember(member);
    await refresh();
  }

  Future<void> saveTransaction({
    String? existingExpenseId,
    String? paidByMemberId,
    TransactionType txType = TransactionType.expense,
    required String title,
    required ExpenseCategory category,
    required double amount,
    required DateTime expenseDate,
    List<String> participantIds = const [],
  }) async {
    final current = state.value;
    final account = current?.activeAccount;
    final cycle = current?.currentCycle;
    if (account == null || cycle == null) return;

    await _repo.saveTransaction(
      existingExpenseId: existingExpenseId,
      accountId: account.id,
      cycleId: cycle.id,
      paidByMemberId: paidByMemberId,
      txType: txType,
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
