import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/utils/category_icon.dart';
import '../../core/utils/formatters.dart';
import '../../providers/app_providers.dart';
import '../widgets/brand_logo.dart';
import 'accounts_screen.dart';
import 'add_expense_screen.dart';
import 'history_screen.dart';
import 'join_group_screen.dart';
import 'personal_ledger_view.dart';
import 'settlement_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final language = ref.watch(appSettingsProvider.select((s) => s.language));
    final dashboard = ref.watch(dashboardProvider).value;
    final account = dashboard?.activeAccount;
    final isPersonal = account?.isPersonal ?? false;

    final pages = isPersonal
        ? const [
            PersonalLedgerTab(),
            PersonalSummaryTab(),
            AccountsScreen(),
          ]
        : [
            _ExpensesTab(onGoToSettle: () => setState(() => _tabIndex = 1)),
            const SettlementScreen(),
            const HistoryScreen(),
            const AccountsScreen(),
          ];

    final titles = isPersonal
        ? [
            account?.name ?? strings.appTitle,
            strings.personalSummaryTitle,
            strings.accountsTitle,
          ]
        : [
            account?.name ?? strings.appTitle,
            strings.settlementTitle,
            strings.historyTitle,
            strings.accountsTitle,
          ];

    final destinations = isPersonal
        ? [
            NavigationDestination(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: const Icon(Icons.account_balance_wallet),
              label: strings.navLedger,
            ),
            NavigationDestination(
              icon: const Icon(Icons.pie_chart_outline),
              selectedIcon: const Icon(Icons.pie_chart),
              label: strings.navSummary,
            ),
            NavigationDestination(
              icon: const Icon(Icons.tune_outlined),
              selectedIcon: const Icon(Icons.tune),
              label: strings.navAccounts,
            ),
          ]
        : [
            NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(Icons.receipt_long),
              label: strings.navExpenses,
            ),
            NavigationDestination(
              icon: const Icon(Icons.balance_outlined),
              selectedIcon: const Icon(Icons.balance),
              label: strings.navSettle,
            ),
            NavigationDestination(
              icon: const Icon(Icons.history_outlined),
              selectedIcon: const Icon(Icons.history),
              label: strings.navHistory,
            ),
            NavigationDestination(
              icon: const Icon(Icons.group_outlined),
              selectedIcon: const Icon(Icons.group),
              label: strings.navAccounts,
            ),
          ];

    final safeIndex = _tabIndex.clamp(0, pages.length - 1);

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 48,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: BrandLogo(size: 32, borderRadius: 10),
          ),
        ),
        title: safeIndex == 0 && account != null
            ? InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _showAccountSwitcherSheet(
                  context,
                  ref,
                  strings,
                  dashboard?.accounts ?? [],
                  account.id,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              titles[safeIndex],
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
                        ],
                      ),
                      Text(
                        isPersonal
                            ? '${strings.personalAccountType} • ${account.currencyCode}'
                            : '${strings.displayCycleTitle(dashboard!.currentCycle!)} • ${dashboard.activeMembers.length} ${strings.membersSection}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              )
            : Text(
                titles[safeIndex],
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
        actions: [
          if (dashboard?.isOfflineFallback == true)
            IconButton(
              tooltip: strings.retryOnlineBtn,
              icon: const Icon(Icons.wifi_off_rounded),
              onPressed: () =>
                  ref.read(dashboardProvider.notifier).retryOnline(),
            ),
          TextButton(
            onPressed: () {
              final next = language == AppLanguage.en
                  ? AppLanguage.my
                  : AppLanguage.en;
              ref.read(appSettingsProvider.notifier).setLanguage(next);
            },
            child: Text(language == AppLanguage.en ? 'မြန်မာ' : 'EN'),
          ),
        ],
      ),
      body: IndexedStack(index: safeIndex, children: pages),
      floatingActionButton: safeIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
                );
              },
              icon: const Icon(Icons.add),
              label: Text(
                isPersonal ? strings.addTransaction : strings.addExpense,
              ),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (idx) => setState(() => _tabIndex = idx),
        destinations: destinations,
      ),
    );
  }

  Future<void> _showAccountSwitcherSheet(
    BuildContext context,
    WidgetRef ref,
    AppStrings strings,
    List<dynamic> accounts,
    String activeAccountId,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text(
                  strings.switchAccount,
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              ...accounts.map((acc) {
                final selected = acc.id == activeAccountId;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: selected
                        ? Theme.of(ctx).colorScheme.primaryContainer
                        : Theme.of(ctx).colorScheme.surfaceContainerHighest,
                    child: Icon(
                      acc.isPersonal
                          ? Icons.account_balance_wallet_outlined
                          : Icons.group_outlined,
                    ),
                  ),
                  title: Text(
                    acc.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${acc.isPersonal ? strings.personalAccountType : strings.groupAccountType} • ${acc.currencyCode}',
                  ),
                  trailing: selected
                      ? Icon(
                          Icons.check_circle,
                          color: Theme.of(ctx).colorScheme.primary,
                        )
                      : null,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    if (!selected) {
                      ref
                          .read(dashboardProvider.notifier)
                          .switchAccount(acc.id);
                    }
                  },
                );
              }),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: Text(strings.createAccount),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CreateAccountScreen(),
                    ),
                  );
                },
              ),
              if (ref.read(dashboardProvider).value?.isCloudMode ?? false)
                ListTile(
                  leading: const Icon(Icons.group_add_outlined),
                  title: Text(strings.joinGroupBtn),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const JoinGroupScreen(),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpensesTab extends ConsumerStatefulWidget {
  final VoidCallback onGoToSettle;

  const _ExpensesTab({required this.onGoToSettle});

  @override
  ConsumerState<_ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends ConsumerState<_ExpensesTab> {
  String _searchQuery = '';
  String? _filterMemberId;

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final dashboard = ref.watch(dashboardProvider).value;

    if (dashboard == null || dashboard.activeAccount == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final account = dashboard.activeAccount!;
    final members = dashboard.members;
    final memberById = {for (final m in members) m.id: m};
    final activeMembers = dashboard.activeMembers;
    final report = dashboard.currentReport;
    final expenses = dashboard.expenses;
    final currency = account.currencyCode;
    final colorScheme = Theme.of(context).colorScheme;

    final filtered = expenses.where((e) {
      if (_filterMemberId != null && e.paidByMemberId != _filterMemberId) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final payerName =
            (memberById[e.paidByMemberId]?.name ?? '').toLowerCase();
        return e.title.toLowerCase().contains(q) || payerName.contains(q);
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Top Cycle Total Card
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary,
                  colorScheme.primary.withValues(alpha: 0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${strings.currentCycle} • ${strings.totalSpent}',
                        style: TextStyle(
                          color: colorScheme.onPrimary.withValues(alpha: 0.85),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppFormatters.formatAmount(
                          report?.totalExpense ?? 0,
                          currency,
                        ),
                        style: TextStyle(
                          color: colorScheme.onPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${strings.perPerson}: ${AppFormatters.formatAmount(report?.averagePerMember ?? 0, currency)}',
                        style: TextStyle(
                          color: colorScheme.onPrimary.withValues(alpha: 0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: widget.onGoToSettle,
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.onPrimary,
                    foregroundColor: colorScheme.primary,
                  ),
                  icon: const Icon(Icons.balance, size: 18),
                  label: Text(strings.navSettle),
                ),
              ],
            ),
          ),
        ),

        // Search & Payer Filter
        if (expenses.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: strings.searchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(strings.all),
                    selected: _filterMemberId == null,
                    onSelected: (_) => setState(() => _filterMemberId = null),
                  ),
                ),
                ...activeMembers.map(
                  (m) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(m.name),
                      selected: _filterMemberId == m.id,
                      onSelected: (selected) {
                        setState(
                          () => _filterMemberId = selected ? m.id : null,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Expense List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 56,
                          color: colorScheme.outline,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          strings.noExpensesYet,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 92),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final expense = filtered[index];
                    final payerName =
                        memberById[expense.paidByMemberId]?.name ?? 'Unknown';
                    final splitCount = expense.splits.isNotEmpty
                        ? expense.splits.length
                        : activeMembers.length;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: colorScheme.primaryContainer,
                          foregroundColor: colorScheme.onPrimaryContainer,
                          child: Icon(iconForExpenseCategory(expense.category), size: 20),
                        ),
                        title: Text(
                          expense.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${strings.paidByLabel}: $payerName  •  ${strings.splitSummary(splitCount, activeMembers.length)}  •  ${AppFormatters.formatShortDate(expense.expenseDate)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              AppFormatters.formatAmount(
                                expense.amount,
                                currency,
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => AddExpenseScreen(
                                        existingExpense: expense,
                                      ),
                                    ),
                                  );
                                } else if (value == 'delete') {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Text(strings.deleteExpenseTitle),
                                      content:
                                          Text(strings.deleteExpenseConfirm),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(false),
                                          child: Text(strings.cancel),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(true),
                                          child: Text(strings.delete),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await ref
                                        .read(dashboardProvider.notifier)
                                        .deleteExpense(expense.id);
                                  }
                                }
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text(strings.edit),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(strings.delete),
                                ),
                              ],
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  AddExpenseScreen(existingExpense: expense),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
